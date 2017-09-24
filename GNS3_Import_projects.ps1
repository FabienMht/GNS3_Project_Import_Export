<#

.Synopsis
   Import des projets GNS3

.DESCRIPTION
   Import des projets GNS3 avec les images,fichiers et machines virtuelles

.EXAMPLE
   ./Nom du script

.INPUTS
   Pas d'entrée en pipe possible

.OUTPUTS
   
.NOTES
    NAME:    Import projets GNS3
    AUTHOR:    Fabien Mauhourat

    VERSION HISTORY:

    1.0     2017.09.12   Fabien MAUHOURAT

.FUNCTIONALITY
    Import des projets GNS3 :
		- Import des fichiers du projet sur le serveur local
		- Import des images du projet dans la VM GNS3 :
			- QEMU
			- IOS
			- DOCKER
			- IOU
		- Import des machines virtuelles du projet

#>

# Définition des variables
# Le dossier d'installation de Putty doit etre dans la variable PATH

[cmdletbinding()]
param (
    [Parameter(Mandatory=$false, Position=1)]
    [Alias("ProjectPath")]
    [string]$gns3_proj_path_local="C:\Users\fabien\GNS3\projects",

    [Parameter(Mandatory=$false, Position=2)]
    [Alias("ProjectZip")]
    [string]$gns3_proj_path_src="C:\Users\fabien\Desktop",

    [Parameter(Mandatory=$false, Position=3)]
    [Alias("IPGns3vm")]
    [string]$ip_vm_gns3="192.168.146.128",

    [string]$gns3_images_path_vm="/opt/gns3/images",

    [string]$pass_gns3_vm="gns3",

    [string]$user_gns3_vm="gns3",

    [string]$vmware_path_ovftool="C:\Program Files (x86)\VMware\VMware Workstation\OVFTool\ovftool.exe",

    # Le chemin absolue des VM doit etre séparé par des doubles "\\"
    [Parameter(Mandatory=$false, Position=4)]
    [Alias("VmwareVmFolder")]
    [string]$vmware_path_vm_folder="C:\\Users\\fabien\\Documents\\Virtual Machines",

    [string]$vbox_path_ovftool="C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",

    [Parameter(Mandatory=$false, Position=5)]
    [Alias("TmpPath")]
    [string]$temp_path="C:\Temp"
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
	
	# Crée le repertoire de travail temporaire
	New-Item -ItemType Directory -Force -Path "$temp_path\GNS3-TEMP" | Out-Null
    if ( $? -eq 0 ) {
        affiche_error "Creation du dossier GNS3-TEMP dans $temp_path echoue !"
        pause ; exit
    }
    $script:temp_path="$temp_path\GNS3-TEMP"

	# Affiche un recap de la configuration en cours
    Write-Host ""
    Write-Host "Verification des parametres terminee sans erreur !" -ForegroundColor Green
    Write-Host ""
    Write-Host "La configuration est la suivante :"
    Write-Host "     * Repertoire temporaire : $temp_path"
    Write-Host "     * Chemin projects : $gns3_proj_path_local"
    Write-Host "     * Chemin images : $gns3_images_path_vm"
    Write-Host "     * Chemin des VMs : $vmware_path_vm_folder"
    Write-Host "     * IpVM GNS3 : $ip_vm_gns3"
    Write-Host ""
}

# Fonction qui verifie les paramètres du script
function verify-param-vm {

        if ( ($($project_file.topology.nodes) | where {$_.node_type -match "vmware"}) -ne $null ) {
            if ( $vmware_path_ovftool -eq "" -or ! (Test-Path $vmware_path_ovftool) ) {
                affiche_error "La variable vmware_path_ovftool n est pas definie ou le chemin n existe pas !"
                delete_temp "$temp_path"
            }
            if ( $vmware_path_vm_folder -eq "" -or ! (Test-Path $vmware_path_vm_folder) ) {
                affiche_error "La variable vmware_path_vm_folder n est pas definie ou le chemin n existe pas !"
                delete_temp "$temp_path"
            }
        }
        if ( ($($project_file.topology.nodes) | where {$_.node_type -match "virtualbox"}) -ne $null ) {
	        if ( $vbox_path_ovftool -eq "" -or ! (Test-Path $vbox_path_ovftool) ) {
                affiche_error "La variable vbox_path_ovftool n est pas definie ou le chemin n existe pas !"
                delete_temp "$temp_path"
            }
        }

}

# Vérification si la place est suffisante sur le disque (taille des vms)
function check_space {

    # Calcul de la taille restante du disque des fichiers temporaire
    $size_disk=(Get-PSDrive "$(($temp_path).Split(':')[0])" | select -ExpandProperty Free) / 1GB

    $vm_vbox_test=$project_file.topology.nodes | where node_type -eq "virtualbox"
    $vm_vmware_test=$project_file.topology.nodes | where node_type -eq "vmware"

    # Calcul de l'espace restant sur le dique d'import des vms
    if ("$vm_vmware_test" -ne "") {
        $size_disk_vmware=(Get-PSDrive "$(($vmware_path_vm_folder).Split(':')[0])" | select -ExpandProperty Free) / 1GB
    }
    if ("$vm_vbox_test" -ne "") {
        $size_disk_vbox=(Invoke-Command {& $vbox_path_ovftool list systemproperties} | where {$_ -match "Default machine folder"}).replace('Default machine folder:          ','')
        $size_disk_vbox=(Get-PSDrive "$(($size_disk_vbox).Split(':')[0])" | select -ExpandProperty Free) / 1GB
    }

    # Calcul de la taille du projet
    $project_size=([System.IO.Compression.ZipFile]::OpenRead("$gns3_proj_path_src\$nom_project.zip").Entries | Measure-Object -property length -sum).Sum /1GB

    $size_after_import=$([int]$size_disk) - $([int]$project_size)

    Write-Host $size_after_import
    Write-Host $project_size
    Write-Host $size_disk
    pause 
    # Si la taille du projet dépasse la taille du disque alors le script s'arrete
    if ([int]$project_size -gt [int]$size_disk) {
        Write-Host ""
        affiche_error "La taille du disque est insuffisante $size_after_import GB pour exporter le projet : $("{0:N1}" -f ($project_size)) GB !"
        delete_temp "$temp_path"
    }

    # Si la taille du projet dépasse la taille du disque ou son stocké les vm vmware alors le script s'arrete
    elseif ( ! (Test-Path variable:\size_disk_vmware) -and ([int]$project_size -gt [int]$size_disk_vmware)) {
        Write-Host ""
        affiche_error "La taille du disque est insuffisante $size_disk_vmware GB pour exporter le projet : $("{0:N1}" -f ($project_size)) GB !"
        delete_temp "$temp_path"
    }

    # Si la taille du projet dépasse la taille du disque ou son stocké les vm vbox alors le script s'arrete
    elseif ( ! (Test-Path variable:\vm_vbox_test) -and ([int]$project_size -gt [int]$size_disk_vbox)) {
        Write-Host ""
        affiche_error "La taille du disque est insuffisante $size_disk_vbox GB pour exporter le projet : $("{0:N1}" -f ($project_size)) GB !"
        delete_temp "$temp_path"
    }

    # Affiche un avertissement si la taille du disque apres exportation atteint une taille définie comme critique
    elseif (([int]$project_size + 10) -gt [int]$size_disk) {

        Write-Host ""
        Write-Warning "La taille du disque est suffisante pour exporter le projet : $("{0:N1}" -f ($project_size)) GB !"
        Write-Warning "Il restera moins de $size_after_import GB sur le disque !"

        Write-Host ""
        $continuer=$(Read-Host "Continuer 0 : non ou 1 : oui")
        Write-Host ""

        if ($continuer -eq 0) {
            affiche_error "La taille du disque est insuffisante pour exporter le projet : $("{0:N1}" -f ($project_size)) GB !"
            delete_temp "$temp_path"
        }
    }
    # Continue le script si la taille du disque est suffisante
    else {
        Write-Host ""
        Write-Host "La taille du disque est suffisante après export : $size_after_import GB !" -ForegroundColor Green
        Write-Host "Taille du projet : $("{0:N1}" -f ($project_size)) GB !" -ForegroundColor Green
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
    plink.exe -pw "$pass_gns3_vm" "$user_gns3_vm@$ip_vm_gns3" "$command" | Out-Null 

    if ( $? -eq 0 ) {
        affiche_error "Commande $command a echoue sur l hote $ip_vm_gns3 avec l utilisateur $user_gns3_vm !"
        delete_temp "$temp_path"
    }
}

# Choix du project GNS3 à Importer
function choix_projets {

    # Choix du project GNS3 à Importer

    Write-Host "Liste des projects GNS3 a importer :" -ForegroundColor Green
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

    Write-Host ""
    $num_project=$(Read-Host "Quel project ")
    Write-Host ""

    # Récuperation du nom du projet en fonction du numero du projet selectionné
    $compteur=0
    Get-ChildItem $gns3_proj_path_src | foreach { 
        if ((Test-Path "$gns3_proj_path_src\$($_.name)") -and ("$($_.name)" -match ".zip")) {
            $compteur=$compteur+1
            if ( $compteur -like $num_project ) {
                $script:nom_project=[System.IO.Path]::GetFileNameWithoutExtension("$($_.Name)")
                return
            }
        }
    }

    Write-Host "Projet $nom_project selectionne !" -ForegroundColor Green

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
choix_projets

# Vérifie si le projet est un projet GNS3
do {
    Add-Type -assembly "system.io.compression.filesystem"
    $test_projet=[System.IO.Compression.ZipFile]::OpenRead("$gns3_proj_path_src\$nom_project.zip").Entries | where Name -Like "*.gns3"

    if ( $test_projet -eq $null ) {
        Write-Host ""
        Write-Warning "Le fichier selectionne n est pas un projet GNS3 !"
        Write-Host ""
        choix_projets
    }
} while ( $test_projet -eq $null )

# Vérifie si la taille du disque est suffisante
check_space

# Decompression du project

Write-Host ""
Write-Host "Decompression de $nom_project en cours !" -ForegroundColor Green

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
Write-Host "Decompression de $nom_project reussi dans $temp_path\$nom_project !" -ForegroundColor Green

# Recuperation du contenu au format JSON du fichier de configuration du projet GNS3
$project_file=Get-Content "$temp_path\$nom_project\$nom_project.gns3" | ConvertFrom-Json

# Import des images du project

$images_path_folder=Get-ChildItem $temp_path\$nom_project\images

# Creation des dossiers des images sur la VM GNS3
foreach ($folder_name in "QEMU","IOU","IOS") {
    ssh_command "mkdir -p $gns3_images_path_vm/$folder_name"
}

# Copie de toutes les images du projet dans la VM GNS3
foreach ($folder in $images_path_folder.Name) {

    Write-Host ""
    Write-Host "Verification des images $folder !"
    Write-Host ""

	# Sidossier d'image vide passage au dossier suivant
    $images_local=Get-ChildItem $temp_path\$nom_project\images\$folder
    if ( "$images_local" -eq "" ) {
        continue
    }

	# Pour les images docker
    if ( "$folder" -eq "docker" ) {
        foreach ($images_docker in $images_local) {

			# Récuperation du chemin de l'image
            $images_ref_path=$images_docker.PSPath | ForEach-Object {$_.split('::')[2] + ":" + $_.split('::')[3]}
            $images_ref_name=$images_docker.name 
			
			# Copie et importation de l'image sur la VM
            ssh_copie "$images_ref_path" "/tmp/$images_ref_name"
            ssh_command "docker load < /tmp/$images_ref_name"

            Write-Host ""
            Write-Host "Import de l image $images_ref_name terminee !" -ForegroundColor Green
            Write-Host ""
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

			# Copue de l'image sur la VM GNS3 dans le bon dossier
            ssh_copie "$images_ref_path" "$gns3_images_path_vm/$folder"
            ssh_command "chmod a+x $gns3_images_path_vm/$folder/$images_ref"

            Write-Host ""
            Write-Host "Import de l image $images_ref terminee !" -ForegroundColor Green
            Write-Host ""
        }
    }
    
}

Write-Host ""
Write-Host "Import des images dans $gns3_images_path_vm terminee avec succes !" -ForegroundColor Green
Write-Host ""

# Import des vm du project en ovf

$vm_path_temp=Get-ChildItem $temp_path -Recurse | where {$_ -match ".ovf$"}

if ("$vm_path_temp" -ne "") {

	# Récuperation du chemin des VMs du projet
    $vm_path=$vm_path_temp.PSPath | ForEach-Object {$_.split('::')[2] + ":" + $_.split('::')[3]}

    # Récuperation des noms des vms vbox du projet
    $vm_vbox_test=$project_file.topology.nodes | where node_type -eq "virtualbox" | select -ExpandProperty properties | select -ExpandProperty vmname

    # Verifie si le projet utilise des vms vmware
    $vm_vmware_test=$project_file.topology.nodes | where node_type -eq "vmware"

	# Importation de toutes les VMs du projet dans le repertoire local des VMs
    foreach ($vm in $vm_path) {

        $test_vbox=0
        Write-Host ""
        Write-Host "Import de la VM $vm en cours !" -ForegroundColor Green
        Write-Host ""

        # Teste si la VM est une vm virtualbox
        foreach ($vm_vbox in $vm_vbox_test) {

            if ("$vm_vbox" -eq "$vm") {

                $test_vbox=1
                Invoke-Command {& $vbox_path_ovftool import "$vm"
                if ( $? -eq 0 ) {
                    affiche_error "Import de la VM virtualbox $vm a echoue !"
                    delete_temp "$temp_path"
                }
                }
            }
        }

        # Si la vm était une vm vbox alors on saute l'import par vmware
        if ($test_vbox -eq 1) {
            continue
        }

		# Command d'import de la VM Vmware
        Invoke-Command {& $vmware_path_ovftool --lax --allowExtraConfig "$vm" "$vmware_path_vm_folder"
        if ( $? -eq 0 ) {
            affiche_error "Import de la VM vmware $vm a echoue !"
            delete_temp "$temp_path"
        }
        }

        # Supression de la vm du repertoire temporaire
        $folder_vm_name=(Get-ChildItem "$vm").Directory.FullName
        delete_temp "$folder_vm_name"
    }

    Write-Host ""
    Write-Host "Import des vm dans $vmware_path_vm_folder terminee avec succes !" -ForegroundColor Green
    Write-Host ""

    # Si le projet utilise Vmware il faut changer le chemin des Vms dans le fichier de dconfiguration de GNS3
    if ( ! ("$vm_vmware_test" -eq "") ) {

        # Backup du fichier du fichier de configuration du projet GNS3

        Copy-Item -Force -Path "$temp_path\$nom_project\$nom_project.gns3" -Destination "$temp_path\$nom_project\$nom_project.gns3.back"

        if ( $? -eq 0 ) {
                affiche_error "Copie du fichier gns3 du projet $temp_path\$nom_project\$nom_project.gns3 echoue !"
                delete_temp "$temp_path"
        }

        # Extrait le chemin des vm à changer dans fichier de configuration du projet

        $vm_path_temp=Get-ChildItem $temp_path

        $vm_path_gns3=Get-Content "$temp_path\$nom_project\$nom_project.gns3.back" | where {$_ -match "vmx"} | ForEach-Object {$_.split('"')[3]}

        foreach ($vm_name in $vm_path_temp.Name) {

            if ("$vm_path_gns3" -match "$vm_name") {
			    # Récuperation de l'ancien chemin des VMs en isolant la premiere partie du chemin
                $old_vm_path=$vm_path_gns3.replace("$vm_name\\$vm_name.vmx",'')
                break
            }
        }

        # Changement du repertoire des vm dans le fichier GNS3 du projet

        $new_gns3_content=Get-Content "$temp_path\$nom_project\$nom_project.gns3.back" | ForEach-Object {$_.replace("$old_vm_path","$vmware_path_vm_folder\\")}

        if ( $? -eq 0 ) {
            affiche_error "Changement du repertoire de la VM $vm_path_projet echoue !"
            delete_temp "$temp_path"
        }

	    # Creation du nouveau fichier de configuration de GNS3 avec le nouveau chemin des VMs
        [System.IO.File]::WriteAllLines("$temp_path\$nom_project\$nom_project.gns3", "$new_gns3_content")

        Write-Host ""
        Write-Host "Changement du repertoire de la VM du projet $nom_project terminee avec succes !" -ForegroundColor Green
        Write-Host ""
    }

}

# Copie du project dans le répertoire local des projets de gns3

Copy-Item -Recurse -Force -Exclude images "$temp_path\$nom_project" "$gns3_proj_path_local\$nom_project"

if ( $? -eq 0 ) {
    affiche_error "Copie du projet $nom_project echoue !"
    delete_temp "$temp_path"
}

Write-Host ""
Write-Host "Copie du projet $nom_project reussi dans $gns3_proj_path_local\$nom_project !" -ForegroundColor Green

# Vidage des fichiers temporaire
delete_temp "$temp_path"

Write-Host ""
Write-Host "Script termine avec succes !" -ForegroundColor Green