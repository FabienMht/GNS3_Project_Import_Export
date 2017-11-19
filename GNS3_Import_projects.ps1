<#

.Synopsis
   Import des projets GNS3

.DESCRIPTION
   Import des projets GNS3 avec les images,fichiers et machines virtuelles
   Fonctionnalités du script d'import :

        - Calcul de l'espace disponnible des disques par rapport à la taille du projet
        - Import du projet dans un fichier zip
        - Import des fichiers du projet

        - Import des images du projet dans la vm GNS3 :
            - QEMU
            - IOS
            - DOCKER
            - IOU

        - Import des machines virtuelles du projet :
            - Machine virtuelles Vmware
            - Machine virtuelles Virtualbox
            - Change le chemin des vms contenue dans le fichier de configuration du projet GNS3

        - Arborescence de l'export
            - Dossier "non_du _projet"
                - Dossier images
                    - IOS
                    - QEMU
                    - IOU
                    - Docker
                - Dossier fichiers du projet
                - Fichier de configuration de GNS3
            - Dossier VM1
            - Dossier VM2
            ...

.EXAMPLE
    Import par défaut les Vms et les images avec le projet
   ./Nom du script

.EXAMPLE
    Pour lancer le script et définir les variables en ligne de commande sans modifier le script
    ./Nom du script -ProjectPath "Path" -ProjectZip "Path" -IPGns3vm "Ip de la VM GNS3" -VmwareVmFolder "Path" -TmpPath "Path"

.INPUTS
   Pas d'entrée en pipe possible

.LINK
    https://github.com/FabienMht/GNS3_Project_Import_Export
 
.NOTES
    NAME:    Import projets GNS3
    AUTHOR:    Fabien Mauhourat
    Version GNS3 : 2.0.3

    VERSION HISTORY:

    1.0     2017.09.12   Fabien MAUHOURAT
    1.1     2017.09.28   Fabien MAUHOURAT   Ajout de la compatibilité Vbox et de la fonction de calcul de l'espace disque
	
#>

# Définition des variables
# Le dossier d'installation de Putty doit etre dans la variable PATH

[cmdletbinding()]
param (

	# Variables à changer
    [Parameter(Mandatory=$false, Position=1)]
    [Alias("ProjectPath")]
    [string]$gns3_proj_path_local="C:\Users\fabien\GNS3\projects",
	
	[Parameter(Mandatory=$false, Position=2)]
    [Alias("ImagesPath")]
    [string]$gns3_images_path_local="C:\Users\fabien\GNS3\images",

    [Parameter(Mandatory=$false, Position=3)]
    [Alias("ProjectZip")]
    [string]$gns3_proj_path_src="C:\Temp",

    [Parameter(Mandatory=$false, Position=4)]
    [Alias("IPGns3vm")]
    [string]$ip_vm_gns3="192.168.0.125",

	# Le chemin absolue des VM doit etre séparé par des doubles "\\"
    [Parameter(Mandatory=$false, Position=5)]
    [Alias("VmwareVmFolder")]
    [string]$vmware_path_vm_folder="C:\\Users\\fabien\\Documents\\Virtual Machines",
	
	[Parameter(Mandatory=$false, Position=6)]
    [Alias("TmpPath")]
    [string]$temp_path="C:\Temp",
	
	# Variable par défaut
    [string]$gns3_images_path_vm="/opt/gns3/images",
	[string]$gns3_projects_path_vm="/opt/gns3/projects",
    [string]$pass_gns3_vm="gns3",
    [string]$user_gns3_vm="gns3",
    [string]$vmware_path_ovftool="C:\Program Files (x86)\VMware\VMware Workstation\OVFTool\ovftool.exe",
    [string]$vbox_path_ovftool="C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

)

# Fonction qui verifie les paramètres du script
function verify-param {

	# Vérifie si la vm GNS3 est joingnable et si les chemins existent
    if ( ! (ping $ip_vm_gns3 -n 2 | Select-String "TTL=") ) {
        affiche_error "La vm GNS3 $ip_vm_gns3 n est pas accessible !"
        pause ; exit
    }
    if ( $gns3_proj_path_local -eq "" -or ! (Test-Path $gns3_proj_path_local) ) {
        affiche_error "La variable gns3_proj_path_local n est pas definie !"
        pause ; exit
    }
	if ( $gns3_images_path_local -eq "" -or ! (Test-Path $gns3_images_path_local) ) {
        affiche_error "La variable gns3_images_path_local n est pas definie !"
        pause ; exit
    }
    if ( $gns3_proj_path_src -eq "" -or ! (Test-Path $gns3_proj_path_src) ) {
        affiche_error "La variable gns3_proj_path_src n est pas definie !"
        pause ; exit
    }
	
	# Verifie si Putty est installé
	if ( ! (Invoke-Command {& plink}) ) {
        affiche_error "Putty n'est pas installe sur le poste ou le chemin n est pas dans la variable PATH !"
        pause ; exit
    }
	if ( ! (Invoke-Command {& pscp}) ) {
        affiche_error "Putty n'est pas installe sur le poste ou le chemin n est pas dans la variable PATH !"
        pause ; exit
    }
	
	# Vérifie si les variables sont nulles
    if ( $temp_path -eq "" ) {
        affiche_error "La variable temp_path n est pas definie !"
        pause ; exit
    }
    if ( $pass_gns3_vm -eq "" ) {
        affiche_error "La variable pass_gns3_vm n est pas definie !"
        pause ; exit
    }
    if ( $user_gns3_vm -eq "" ) {
        affiche_error "La variable user_gns3_vm n est pas definie !"
        pause ; exit
    }
    if ( $gns3_images_path_vm -eq "" ) {
        affiche_error "La variable gns3_images_path_vm n est pas definie !"
        pause ; exit
    }
	if ( $gns3_projects_path_vm -eq "" ) {
        affiche_error "La variable gns3_projects_path_vm n est pas definie !"
        pause ; exit
    }
	
    # Supprime le répertoire temporaire s'il existe
    if (Test-Path "$temp_path\GNS3-TEMP") {
        Remove-Item -Force -Recurse "$temp_path\GNS3-TEMP\*"
        if ( $? -eq 0 ) {
            affiche_error "Creation du dossier GNS3-TEMP dans $temp_path echoue !"
            pause ; exit
        }
    }

	# Crée le repertoire de travail temporaire
	New-Item -ItemType Directory -Force -Path "$temp_path\GNS3-TEMP" | Out-Null
    if ( $? -eq 0 ) {
        affiche_error "Creation du dossier GNS3-TEMP dans $temp_path echoue !"
        pause ; exit
    }
    $script:temp_path="$temp_path\GNS3-TEMP"

	# Affiche un recap de la configuration en cours
    Write-Host ""
    Write-Host "Verification des parametres terminee sans erreur :" -ForegroundColor Green
    Write-Host ""
    Write-Host "La configuration est la suivante :"
    Write-Host "     * Repertoire temporaire : $temp_path"
    Write-Host "     * Chemin projects : $gns3_proj_path_local"
    Write-Host "     * Chemin images : $gns3_images_path_vm"
    Write-Host "     * IpVM GNS3 : $ip_vm_gns3"
}

# Fonction qui verifie les paramètres du script
function verify-param-vm {

        # Vérifie les paramètres si le projet utilise Vmware
        if ( "$vm_vmware" -ne "" ) {
            if ( $vmware_path_ovftool -eq "" -or ! (Test-Path $vmware_path_ovftool) ) {
                affiche_error "La variable vmware_path_ovftool n est pas definie ou le chemin n existe pas !"
                delete_temp "$temp_path"
            }
            if ( $vmware_path_vm_folder -eq "" -or ! (Test-Path $vmware_path_vm_folder) ) {
                affiche_error "La variable vmware_path_vm_folder n est pas definie ou le chemin n existe pas !"
                delete_temp "$temp_path"
            }

            #Vérifie si le chemin des Vm contient deux "\\"
            $split_path=$vmware_path_vm_folder.Split('\')
            $vmware_path_vm_folder=""

            0..($split_path.Length - 1) | foreach {

                if ($split_path[$_] -ne "") {

                    if ($_ -ne 0 ) {
                        $vmware_path_vm_folder=$vmware_path_vm_folder + "\\$($split_path[$_])"
                    } else {
                        $vmware_path_vm_folder=$vmware_path_vm_folder + "$($split_path[$_])"
                    }
                }
            }
            $show_config="     * Chemin des VMs Vmware : $vmware_path_vm_folder"
        }

        # Vérifie les paramètres si le projet utilise Vbox
        if ( "$vm_vbox" -ne "" ) {
	        if ( $vbox_path_ovftool -eq "" -or ! (Test-Path $vbox_path_ovftool) ) {
                affiche_error "La variable vbox_path_ovftool n est pas definie ou le chemin n existe pas !"
                delete_temp "$temp_path"
            }
            $script:path_disk_vbox=(Invoke-Command {& $vbox_path_ovftool list systemproperties} | where {$_ -match "Default machine folder"}).replace('Default machine folder:          ','')
            $show_config="     * Chemin des VMs Vbox : $path_disk_vbox"
        }

        if ( ("$vm_vmware" -ne "") -or ("$vm_vbox" -ne "") ) {

            # Affiche un recap de la configuration en cours
            Write-Host ""
            Write-Host "Verification des parametres des Vms terminee sans erreur :" -ForegroundColor Green
            Write-Host ""
            Write-Host "La configuration est la suivante :"
            Write-Host $show_config
        }
}

# Vérification si la place est suffisante sur le disque (taille des vms)
function show_space {

    Param(
      [string]$size_disk,
      [single]$project_size
    )

    $size_after_import=$([int]$size_disk) - $([int]$project_size)

    # Si la taille du projet dépasse la taille du disque alors le script s'arrete
    if ([int]$project_size -gt [int]$size_disk) {
        Write-Host ""
        affiche_error "La taille du disque est insuffisante $size_after_import GB pour importer le projet : $("{0:N1}" -f ($project_size)) GB !"
        delete_temp "$temp_path"
    }

    # Affiche un avertissement si la taille du disque apres exportation atteint une taille définie comme critique
    elseif (([int]$project_size + 10) -gt [int]$size_disk) {

        Write-Host ""
        Write-Warning "La taille du disque est suffisante pour importer le projet : $("{0:N1}" -f ($project_size)) GB !"
        Write-Warning "Il restera moins de $size_after_import GB sur le disque !"

        Write-Host ""
        $continuer=$(Read-Host "Continuer ( 0 : non ou 1 : oui ) ")
        Write-Host ""

        if ($continuer -eq 0) {
            affiche_error "La taille du disque est insuffisante pour importer le projet : $("{0:N1}" -f ($project_size)) GB !"
            delete_temp "$temp_path"
        }
    }
    # Continue le script si la taille du disque est suffisante
    else {
        Write-Host ""
        Write-Host "La taille du disque est suffisante après import : $size_after_import GB !"
        Write-Host "Taille du projet : $("{0:N1}" -f ($project_size)) GB !"
    }

}

# Vérification si la place est suffisante sur le disque (taille des vms)
function check_space {
    
    Write-Host ""
    Write-Host "La taille du projet :" -ForegroundColor Green

    # Récuperation de la lettre des lecteurs
    $root_temp="$(($temp_path).Split(':')[0])"

    # Calcul de la taille restante du disque des fichiers temporaire
    $size_disk=(Get-PSDrive $root_temp | select -ExpandProperty Free) / 1GB

    # Calcul de la taille du projet
    $project_size=([System.IO.Compression.ZipFile]::OpenRead("$gns3_proj_path_src\$nom_project.zip").Entries | Measure-Object -property length -sum).Sum /1GB

    # Calcul de l'espace restant sur le dique d'import des vms
    if ("$vm_vmware" -ne "") {

        # Récuperation de la lettre des lecteurs
        $root_vmware="$(($vmware_path_vm_folder).Split(':')[0])"

        if ( "$root_vmware" -eq "$root_temp" ) {
            $project_size=$project_size * 2
            show_space $size_disk $project_size
        } else {
            foreach ($disk in "$root_temp","$root_vmware") {
                # Calcul de la taille restante du disque des fichiers temporaire
                $size_disk=(Get-PSDrive "$disk" | select -ExpandProperty Free) / 1GB
                show_space $size_disk $project_size
            }
        }
    }
    elseif ("$vm_vbox" -ne "") {
        
        # Récuperation de la lettre des lecteurs
        $root_vbox="$(($path_disk_vbox).Split(':')[0])"

        if ( "$root_vbox" -eq "$root_temp" ) {
            $project_size=$project_size * 2
            show_space $size_disk $project_size
            
        } else {
            foreach ($disk in "$root_temp","$root_vmware") {
                # Calcul de la taille restante du disque des fichiers temporaire
                $size_disk=(Get-PSDrive "$disk" | select -ExpandProperty Free) / 1GB
                show_space $size_disk $project_size
            }
        }
    }
    else {
        show_space $size_disk $project_size
    }

}


# Fonction qui copie les images du project en ssh
function ssh_copie {

    Param(
      [string]$source,
      [string]$dest
    )

	# Commande scp avec Putty
    pscp.exe -pw $pass_gns3_vm -r "$source" "$user_gns3_vm@$($ip_vm_gns3):$dest" | Out-Null

    if ( $? -eq 0 ) {
        affiche_error "Import de l image $images echoue !"
        delete_temp "$temp_path"
    }
}

# Fonction qui execute une commande ssh
function ssh_command {

    Param(
      [string]$command
    )

	# Commande SSH avec Putty
    plink.exe -pw "$pass_gns3_vm" "$user_gns3_vm@$ip_vm_gns3" "$command"

    if ( $? -eq 0 ) {
        affiche_error "Commande $command a echoue sur l hote $ip_vm_gns3 avec l utilisateur $user_gns3_vm !"
        delete_temp "$temp_path"
    }
}

# Choix du project GNS3 à Importer
function choix_projets {

    # Choix du project GNS3 à Importer

    Write-Host ""
    Write-Host "1. Liste des projects GNS3 a importer :" -ForegroundColor Green
    Write-Host ""

    # Liste les projets GNS3 du repertoire gns3_proj_path_local
    $compteur=0
    # Affichage de tous les fichiers qui sont au format ZIP
    Get-ChildItem $gns3_proj_path_src | select Name | foreach { 
        if ((Test-Path "$gns3_proj_path_src\$($_.name)") -and ("$($_.name)" -match ".zip")) {
            $compteur=$compteur+1
            Write-Host "$compteur." $_.name`
        }
    }

    do {
        Write-Host ""
        $num_project=$(Read-Host "Quel project ")
    } while ( ($num_project -eq "") -or ($num_project -gt $compteur) )

    # Récuperation du nom du projet en fonction du numero du projet selectionné
    $compteur=0
    Get-ChildItem $gns3_proj_path_src | foreach { 

        if ((Test-Path "$gns3_proj_path_src\$($_.name)") -and ("$($_.name)" -match ".zip")) {

            $compteur=$compteur+1
            if ( $compteur -like $num_project ) {

                $test_projet=[System.IO.Compression.ZipFile]::OpenRead("$gns3_proj_path_src\$($_.Name)").Entries | where Name -Like "*.gns3"

                if ( $test_projet -eq $null ) {

                    Write-Host ""
                    Write-Warning "Le fichier selectionne n est pas un projet GNS3 !"
                    choix_projets

                } else {
                    $script:nom_project=[System.IO.Path]::GetFileNameWithoutExtension("$($_.Name)")

                    # Vérifie si le projet existe déjà sur le poste
                    if ( Test-Path "$gns3_proj_path_local\$nom_project\$nom_project.gns3" ) {

                        Write-Host ""
                        Write-Warning "Le projet $nom_project existe deja sur le poste : $gns3_proj_path_local\$nom_project !"

                        Write-Host ""
                        $continuer=$(Read-Host "Supprimer le projet sur le poste ( 0 : non ou 1 : oui ) ")

                        if ($continuer -eq 1) {
                            Remove-Item -Force -Recurse -Confirm "$gns3_proj_path_local\$nom_project"
                        } else {
                            affiche_error "Le projet $nom_project existe deja sur le poste : $gns3_proj_path_local\$nom_project !"
                            delete_temp "$temp_path"
                        }
                    }
                }
            }
        }
    }
}

# Fonction qui affiche les erreurs du script
function affiche_error {

    Write-Host ""
    Write-Error "$args"
    Write-Host ""

}

# Fonction qui supprime les fichiers temporaires du script
function delete_temp {

    Param(
      [string]$path
    )

    Remove-Item -Force -Recurse "$path"
    pause ; exit

}

write-output "###########################################################################"
write-output "################## Script d Importation des projets GNS3 ##################"
write-output "###########################################################################"

# Vérification des paramètres
verify-param

# Choix du project GNS3 à Importer
Add-Type -assembly "system.io.compression.filesystem"
choix_projets

Write-Host ""
Write-Host "Projet $nom_project selectionne !" -ForegroundColor Green

# Récuperation du contenu du fichier de configuration de GNS3
$project_conf=[System.IO.Compression.ZipFile]::OpenRead("$gns3_proj_path_src\$nom_project.zip").Entries | where name -Match "$nom_project.gns3"

$file=$project_conf.open()

$dest=New-Object IO.FileStream ("$temp_path\$nom_project.txt") ,'Append','Write','Read'

$file.copyto($dest)

if ( $? -eq 0 ) {
	affiche_error "Recuperation du contenu du fichier de configuration de GNS3 echoue !"
	delete_temp "$temp_path"
}

$file.close()
$dest.close()

# Recuperation du contenu au format JSON du fichier de configuration du projet GNS3
$project_file=Get-Content "$temp_path\$nom_project.txt" | ConvertFrom-Json

if ( $? -eq 0 ) {
	affiche_error "Recuperation du contenu du fichier de configuration de GNS3 echoue !"
	delete_temp "$temp_path"
}

Remove-Item -Force "$temp_path\$nom_project.txt"

$vm_vbox=$project_file.topology.nodes | where node_type -eq "virtualbox"
$vm_vmware=$project_file.topology.nodes | where node_type -eq "vmware"

# Vérification des paramètres pour les vms
verify-param-vm

# Vérifie si la taille du disque est suffisante
check_space

# Decompression du project
Write-Host ""
Write-Host "2. Decompression de $nom_project en cours :" -ForegroundColor Green

# Décompression pour powershell 5 et anterieur
if ((Get-Host | select -ExpandProperty Version | select -ExpandProperty major) -eq 5){

    # Décompression du zip pour powershell 5
    Expand-Archive -Force -Path "$gns3_proj_path_src\$nom_project.zip" -DestinationPath "$temp_path\"

    if ( $? -eq 0 ) {
        affiche_error "Decompression du projet $nom_project echoue !"
        delete_temp "$temp_path"
    }
} else {

    # Décompresson pour les autres versions de Powershell
    Add-Type -Assembly "System.IO.Compression.FileSystem"
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$gns3_proj_path_src\$nom_project.zip", "$temp_path\")

    if ( $? -eq 0 ) {
        affiche_error "Decompression du projet $nom_project echoue !"
        delete_temp "$temp_path"
    }
}

Write-Host ""
Write-Host "Decompression de $nom_project reussi dans $temp_path\$nom_project !"

# Recuperation du contenu au format JSON du fichier de configuration du projet GNS3
$project_file=Get-Content "$temp_path\$nom_project\$nom_project.gns3" | ConvertFrom-Json


$imges_test=Get-ChildItem -Recurse "$temp_path\$nom_project\images" | where mode -NotMatch "^d"

# Si le projet comporte des images
if ("$imges_test" -ne "") {

    # Import des images du project

    $images_path_folder=Get-ChildItem "$temp_path\$nom_project\images"

    $folder_vm=$(plink.exe -pw "$pass_gns3_vm" "$user_gns3_vm@$ip_vm_gns3" "ls -l $gns3_images_path_vm | grep '^d'")

    # Creation des dossiers des images sur la VM GNS3
    foreach ($folder_name in "QEMU","IOU","IOS") {
        if ( ! ($folder_vm | ? {$_ -match "$folder_name"}) ) {
            ssh_command "mkdir -p $gns3_images_path_vm/$folder_name"
        }
    }

    Write-Host ""
    Write-Host "3. Import des images dans $gns3_images_path_vm en cours :" -ForegroundColor Green

    # Copie de toutes les images du projet dans la VM GNS3
    foreach ($folder in $images_path_folder.Name) {

	    # Si dossier d'image vide passage au dossier suivant
        $images_local=Get-ChildItem "$temp_path\$nom_project\images\$folder"
        if ( "$images_local" -eq "" ) {
            continue
        }

        Write-Host ""
        Write-Host "Verification des images $folder :"  -ForegroundColor Green

	    # Pour les images docker
        if ( "$folder" -eq "docker" ) {
            foreach ($images_docker in $images_local) {

			    # Récuperation du chemin de l'image
                $images_ref_path=$images_docker.PSPath | ForEach-Object {$_.split('::')[2] + ":" + $_.split('::')[3]}
                $images_ref_name=$images_docker.name
                $images_ref_name_docker=$images_ref_name.replace('.tar','')
			
                $docker_images=$(plink.exe -pw "$pass_gns3_vm" "$user_gns3_vm@$ip_vm_gns3" "docker images | grep $images_ref_name_docker")

                # Pour les images docker
                if ( "$docker_images" -ne "" ) {
                    Write-Host ""
                    Write-Host "L image $images_ref_name_docker existe deja sur la VM GNS3 !"
                    continue
                }

                Write-Host ""
                Write-Host "Import de l image $images_ref_name_docker en cours !"

			    # Copie et importation de l'image sur la VM
                ssh_copie "$images_ref_path" "/tmp/$images_ref_name"
                ssh_command "docker load < /tmp/$images_ref_name"
            
            }
            continue
        }

        $images_vm=ssh_command "ls $gns3_images_path_vm/$folder" | where {$_ -notmatch "md5sum"}

	    # Pour le reste des images IOS,IOU,QEMU
        ForEach ($images_ref in $images_local.Name) {
            $test_images=0

		    # Vérifie si l'image est déjà présente sur la vm GNS3
            ForEach ($images_dest in $images_vm) {

                if ("$images_ref" -like "$images_dest") {
                    $test_images=1
                    break
                }
            }

            if ($test_images -ne 1) {
            
			    # Récuperation du chemin de l'image
                $images_ref_path=$images_local.PSPath | where {$_ -match "$images_ref"} | ForEach-Object {$_.split('::')[2] + ":" + $_.split('::')[3]}

                Write-Host ""
                Write-Host "Import de l image $images_ref en cours !"

			    # Copue de l'image sur la VM GNS3 dans le bon dossier
                ssh_copie "$images_ref_path" "$gns3_images_path_vm/$folder"
                ssh_command "chmod a+x $gns3_images_path_vm/$folder/$images_ref"
            }
            else {
                Write-Host ""
                Write-Host "Limage $images_ref est daja presente sur la VM GNS3 !"
            }
        }
    
    }

    Write-Host ""
    Write-Host "Import des images dans $gns3_images_path_vm terminee avec succes !" -ForegroundColor Green
	
	Copy-Item -Recurse -Force -Exclude docker "$temp_path\$nom_project\images\*" "$gns3_images_path_local\"

}
# Import des vm du project en ovf

$vm_path_temp=Get-ChildItem $temp_path -Recurse | where {$_ -match ".ovf$"}

if ("$vm_path_temp" -ne "") {

    Write-Host ""
    Write-Host "4. Import des VMs en cours :" -ForegroundColor Green

    # Récuperation des noms des vms vbox du projet
    $vm_vbox_test=$project_file.topology.nodes | where node_type -eq "virtualbox" | select -ExpandProperty properties | select -ExpandProperty vmname

    # Verifie si le projet utilise des vms vmware
    $vm_vmware_test=$project_file.topology.nodes | where node_type -eq "vmware"

	# Importation de toutes les VMs du projet dans le repertoire local des VMs
    foreach ($vm in $vm_path_temp) {
        
        # Récuperation du chemin des VMs du projet
        $vm_path=$vm.fullname
        $vm_name=$vm.directory.name

        $test_vbox=0
        Write-Host ""
        Write-Host "Import de la VM $vm_name en cours :" -ForegroundColor Green
        Write-Host ""

        # Teste si la VM est une vm virtualbox
        foreach ($vm_vbox in $vm_vbox_test) {

            if ("$vm_vbox" -eq "$vm_path") {

                $test_vbox=1
                # Commande d'import de la VM Vbox
                Invoke-Command {& $vbox_path_ovftool import "$vm_path"
                if ( $? -eq 0 ) {
                    affiche_error "Import de la VM virtualbox $vm_name a echoue !"
                    delete_temp "$temp_path"
                }
                }
                # Supression de la vm du repertoire temporaire
                $folder_vm_name=(Get-ChildItem "$vm_path").Directory.FullName
                Remove-Item -Force -Recurse "$folder_vm_name"
            }
        }

        # Si la vm était une vm vbox alors on saute l'import par vmware
        if ($test_vbox -eq 1) {
            continue
        }

		# Test si la vm existe déjà
        #if ( Test-Path "$vmware_path_vm_folder\$vm_name\$($($vm.name).replace('.ovf','.vmx'))" ) {
        if ( Test-Path "$vmware_path_vm_folder\$vm_name" ) {

            Write-Warning "La vm $vm_name existe déja sur le disque !"

            Write-Host ""
            $continuer=$(Read-Host "Supprimer le projet sur le poste ( 0 : non ou 1 : oui ) ")

            if ($continuer -eq 1) {
                Remove-Item -Force -Recurse -Confirm "$vmware_path_vm_folder\$vm_name"
                if ( $? -eq 0 ) {
                    affiche_error "Suppression de la VM vmware $vm_name a echoue !"
                    delete_temp "$temp_path"
                }
                Write-Host ""
            } else {
                affiche_error "Import de la VM vmware $vm_name a echoue !"
                delete_temp "$temp_path"
            }   
        }

        # Commande d'import de la VM Vmware
        Invoke-Command {& $vmware_path_ovftool\OVFTool\ovftool.exe --lax --allowExtraConfig "$vm_path" "$vmware_path_vm_folder"
        if ( $? -eq 0 ) {
            affiche_error "Import de la VM vmware $vm_name a echoue !"
            delete_temp "$temp_path"
        }
        }
		
        Invoke-Command {& $vmware_path_ovftool\vmware.exe "$vmware_path_vm_folder\$vm_name\$vm_name.vmx"
        if ( $? -eq 0 ) {
            affiche_error "Import de la VM vmware $vm_name a echoue !"
            delete_temp "$temp_path"
        }
        }
    }

    Write-Host ""
    Write-Host "Import des vm dans $vmware_path_vm_folder terminee avec succes !" -ForegroundColor Green

    # Si le projet utilise Vmware il faut changer le chemin des Vms dans le fichier de configuration de GNS3
    if ( "$vm_vmware" -ne "" ) {

        # Backup du fichier du fichier de configuration du projet GNS3

        Copy-Item -Force -Path "$temp_path\$nom_project\$nom_project.gns3" -Destination "$temp_path\$nom_project\$nom_project.gns3.back"

        if ( $? -eq 0 ) {
                affiche_error "Copie du fichier gns3 du projet $temp_path\$nom_project\$nom_project.gns3 echoue !"
                delete_temp "$temp_path"
        }

        # Extrait le chemin des vm à changer dans fichier de configuration du projet

        $vm_path_temp=Get-ChildItem "$temp_path"
        $vm_path_gns3=Get-Content "$temp_path\$nom_project\$nom_project.gns3.back" | where {$_ -match "vmx"} | foreach {$_.split('"')[3]} | select -First 1
        if ( $? -eq 0 ) {
            affiche_error "Recuperation de l ancien chemin des VMs du projet echoue !"
            delete_temp "$temp_path"
        }

        foreach ($vm_name in $vm_path_temp.Name) {

            if ("$vm_path_gns3" -match "$vm_name") {
			    # Récuperation de l'ancien chemin des VMs en isolant la premiere partie du chemin
                $old_vm_path="$vm_path_gns3".replace("$vm_name\\$vm_name.vmx",'')
                break
            }
        }

        # Changement du repertoire des vm dans le fichier GNS3 du projet

        $new_gns3_content=Get-Content "$temp_path\$nom_project\$nom_project.gns3.back" | ForEach-Object {
        $_.replace("$old_vm_path","$vmware_path_vm_folder\\")
        if ( $? -eq 0 ) {
            affiche_error "Changement du repertoire de la VM $vm_path_projet echoue !"
            delete_temp "$temp_path"
        }
        }

	    # Creation du nouveau fichier de configuration de GNS3 avec le nouveau chemin des VMs
        [System.IO.File]::WriteAllLines("$temp_path\$nom_project\$nom_project.gns3", "$new_gns3_content")

        Write-Host ""
        Write-Host "Changement du repertoire de la VM du projet $nom_project terminee avec succes !" -ForegroundColor Green
    }

}

# Copie du project dans le répertoire local des projets de gns3

New-Item -ItemType Directory -Force -Path "$gns3_proj_path_local\$nom_project" | Out-Null
Copy-Item -Recurse -Force -Exclude images "$temp_path\$nom_project\*" "$gns3_proj_path_local\$nom_project"

if ( $? -eq 0 ) {
    affiche_error "Copie du projet $nom_project echoue !"
    delete_temp "$temp_path"
}

Write-Host ""
Write-Host "Copie du projet $nom_project reussi dans $gns3_proj_path_local\$nom_project !" -ForegroundColor Green

# Création du répertoire du projet sur la vm gns3
ssh_command "mkdir -p $gns3_projects_path_vm/$($project_file.project_id)/project-files"

# Copie du project dans le répertoire de la vm gns3 des projets de gns3
ssh_copie "$gns3_proj_path_local\$nom_project\project-files\" "$gns3_projects_path_vm/$($project_file.project_id)/project-files"

Write-Host ""
Write-Host "Copie du projet $nom_project reussi dans gns3_projects_path_vm/$($project_file.project_id) !" -ForegroundColor Green

# Vidage des fichiers temporaire
Remove-Item -Force -Recurse "$temp_path"

Write-Host ""
Write-Host "Script termine avec succes !" -ForegroundColor Green