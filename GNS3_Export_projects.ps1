<#

.Synopsis
   Export des projets GNS3

.DESCRIPTION
   Export des projets GNS3 avec les images,fichiers et machines virtuelles
   Fonctionnalités du script d'export :

        - Calcul de l'espace disponnible des disques par rapport à la taille du projet
        - Export des fichiers du projet contenue dans la VM GNS3

        - Export des images du projet :
            - QEMU
            - IOS
            - DOCKER
            - IOU

        - Export des machines virtuelles du projet :
            - Machine virtuelles Vmware
            - Machine virtuelles Virtualbox
            - Change la mention Use_any_adapter de GNS3 du fichier deconfiguration du projet de false à true (Compatibilité import)

        - Export du projet dans un fichier zip

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
   Inclut par défaut les Vms et les images avec le projet
   ./Nom du script

.EXAMPLE
    Pour ne pas inclure les images dans l'export du projet
    ./Nom du script -IncludeImages $false

.EXAMPLE
    Pour lancer le script et définir les variables en ligne de commande sans modifier le script
    ./Nom du script -ProjectPath "Path" -ImagesPath "Path" -IPGns3vm "Ip de la VM GNS3" -TmpPath "Path" -ExportPath "Path"

.INPUTS
   Pas d'entrée en pipe possible

.LINK
    https://github.com/FabienMht/GNS3_Project_Import_Export

.NOTES
    NAME:    Export projets GNS3
    AUTHOR:    Fabien Mauhourat
    Version GNS3 : 2.0.3

    VERSION HISTORY:

    1.0     2017.09.12   Fabien MAUHOURAT
    1.1     2017.09.28   Fabien MAUHOURAT

#>

# Définition des variables
# Le dossier d'installation de Putty doit etre dans la variable PATH

[cmdletbinding()]
param (

    [parameter(Mandatory=$false)]
    [string]$IncludeImages=$true,

    # Variables à changer
    [Parameter(Mandatory=$false, Position=1)]
    [Alias("ProjectPath")]
    [string]$gns3_proj_path_local="D:\Soft\GNS3\projects",

    [Parameter(Mandatory=$false, Position=2)]
    [Alias("ImagesPath")]
    [string]$gns3_images_path_local="D:\Soft\GNS3\images",

    [Parameter(Mandatory=$false, Position=3)]
    [Alias("IPGns3vm")]
    [string]$ip_vm_gns3="192.168.0.50",

    [Parameter(Mandatory=$false, Position=4)]
    [Alias("TmpPath")]
    [string]$temp_path="E:\Temp",

    [Parameter(Mandatory=$false, Position=5)]
    [Alias("ExportPath")]
    [string]$export_project_path="C:\Temp",

    # Variables par défaut
    [string]$gns3_proj_path_vm="/opt/gns3/projects",
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
    # Si les images doivent être incluse au projet
    if ($IncludeImages -eq $true) {
        if ( $gns3_images_path_local -eq "" -or ! (Test-Path $gns3_images_path_local) ) {
            affiche_error "La variable gns3_images_path_local n est pas definie !"
            pause ; exit
        }
        if ( $gns3_proj_path_vm -eq "" ) {
            affiche_error "La variable gns3_proj_path_vm n est pas definie !"
            pause ; exit
        }
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
    if ( $export_project_path -eq "" ) {
        affiche_error "La variable export_project_path n est pas definie !"
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
	
    # Crée le repertoire d'export
	New-Item -ItemType Directory -Force -Path "$export_project_path" | Out-Null
    if ( $? -eq 0 ) {
        affiche_error "Creation du dossier $export_project_path echoue !"
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
    Write-Host "Verification des parametres terminee sans erreur :" -ForegroundColor Green
    Write-Host ""
    Write-Host "La configuration est la suivante :"
    Write-Host "     * Chemin projects : $gns3_proj_path_local"
    if ($IncludeImages -eq $true) {
        Write-Host "     * Chemin images : $gns3_images_path_local"
    }
    Write-Host "     * Chemin temporaire du project : $temp_path"
    Write-Host "     * Chemin d export du project : $export_project_path"
    Write-Host "     * IpVM GNS3 : $ip_vm_gns3"
    Write-Host ""
}

# Fonction qui verifie les paramètres du script
function verify-param-vm {

        # Si le projet utilise Vmware : verifie la variable du chemin de l'utilitaire ovftool
        if ( ($vm_project | where {$_.node_type -match "vmware"}) -ne $null ) {
            if ( $vmware_path_ovftool -eq "" -or ! (Test-Path $vmware_path_ovftool) ) {
                affiche_error "La variable vmware_path_ovftool n est pas definie ou le chemin n existe pas !"
                delete_temp
            }
        }

        # Si le projet utilise Vbox : verifie la variable du chemin de l'utilitaire vboxmanage
        if ( ($vm_project | where {$_.node_type -match "virtualbox"}) -ne $null ) {
	        if ( $vbox_path_ovftool -eq "" -or ! (Test-Path $vbox_path_ovftool) ) {
                affiche_error "La variable vbox_path_ovftool n est pas definie ou le chemin n existe pas !"
                delete_temp
            }
        }

}

# Vérification si la place est suffisante sur le disque (taille des vms seulement pour les VM Vmware et Vbox)
function check_space {

    Write-Host ""
    Write-Host "La taille du projet :" -ForegroundColor Green

    # Calcul de la taille du projet après exportation
    foreach ($vm in $($vm_project)) {
        
        # Récuperation du chemin des vms du projet
        if ($($vm.node_type) -match "virtualbox") {

            $vm_path=Invoke-Command {& $vbox_path_ovftool showvminfo "$($vm.properties.vmname)"} | ? {$_ -match "Config file"}
            if ( $? -eq 0 ) {
                affiche_error "Calcul de la taille de la VM $($vm.properties.vmname) echoue !"
                delete_temp
            }
            $vm_path=$vm_path.Replace('Config file:     ','')
        } else {
            $vm_path=$($vm.properties.vmx_path)
        }
        $folder_vm_name=(Get-ChildItem "$vm_path").Directory.FullName

        # Calcul la taille du dossier ou sont stockées les Vms
        $folder_size=$folder_size + ((Get-ChildItem "$folder_vm_name" -recurse | Where { -not $_.PSIsContainer } | Measure-Object -property length -sum).Sum / 1GB)
    }

    # Récuperation des lettres des lecteurs
    $root_temp="$(($temp_path).Split(':')[0])"
    $root_export="$(($export_project_path).Split(':')[0])"

    # Vérifie si les lettres de lecteur sont les mêmes
    if ("$root_temp" -eq "$root_export") {
        $root_test=1
        $folder_size=$folder_size * 2
    }

    Write-Host ""
    Write-Host "Taille du projet : $("{0:N1}" -f ($folder_size)) GB !" -ForegroundColor Green
    Write-Host "Taille du projet apres export : $("{0:N1}" -f ($folder_size * 80 / 100)) GB !" -ForegroundColor Green

    # Verifie pour chaque disque que la taille est suffisante en fonction du projet
    foreach ($disk in "$root_temp","$root_export") {

        
        $size_disk=(Get-PSDrive "$(($disk).Split(':')[0])" | select -ExpandProperty Free) / 1GB
        $size_after_export=$([int]$size_disk) - $([int]$folder_size)

        # Si la taille du projet dépasse la taille du disque alors le script s'arrete
        if ([int]$folder_size -gt [int]$size_disk) {

            Write-Host ""
            affiche_error "La taille du disque $disk est insuffisante $size_after_export GB pour exporter le projet : $("{0:N1}" -f ($folder_size)) GB !"

            # Vérifie l'espace libre des autres disques
            $other_disk=Get-PSDrive -PSProvider FileSystem | where {$_.Name -notmatch "$disk"} | Select name,free

            foreach ($disk_back in $($other_disk)) {
                if ([int]$folder_size -gt [int]($disk_back.free / 1GB)) {
                    continue
                }
                else {
                    Write-Host ""
                    Write-Host "La taille du disque $($disk_back.name) est suffisante pour exporter le projet !"
                }
            }
            
            delete_temp
        }

        # Affiche un avertissement si la taille du disque apres exportation atteint une taille définie comme critique
        elseif (([int]$folder_size + 10) -gt [int]$size_disk) {

            Write-Host ""
            Write-Warning "La taille du disque $disk est suffisante pour exporter le projet : $("{0:N1}" -f ($folder_size)) GB !"
            Write-Warning "Il restera moins de $size_after_export GB sur le disque !"

            Write-Host ""
            $continuer=$(Read-Host "Continuer 0 : non ou 1 : oui")
            Write-Host ""

            if ($continuer -eq 0) {
                affiche_error "La taille du disque $disk est insuffisante pour exporter le projet : $("{0:N1}" -f ($folder_size)) GB !"
                delete_temp
            }
        }
        # Continue le script si la taille du disque est siffisante
        else {
            Write-Host ""
            Write-Host "La taille du disque $disk est suffisante après export : $size_after_export GB !"
        }
        if ($root_test -eq 1) {
            break
        }
    }

}

# Fonction qui copie les images du project du repertoire ou elles sont stockées vers le repertoire temporaire
function copie-images {

    Param(
      [string]$source,
      [string]$dest,
      [string]$images_name
    )
    
    Write-Host ""
    Write-Host "Export de l image $images_name en cours !" -ForegroundColor Green

    Copy-Item -Force -Path "$source" -Destination "$temp_path\$nom_project\images\$dest"
    
    if ( $? -eq 0 ) {
        affiche_error "Export de l image $images_name echoue !"
        delete_temp
    }
}

# Fonction qui verifie si l image existe dans le repertoire temporaire
function verify_images {

    Param(
      [string]$images_name,
      [string]$type
    )

    $images_test=Get-ChildItem -Path "$temp_path\$nom_project\images\$type" | where {$_ -match "^$($images_name)$"}
    return "$images_test"
}

# Fonction qui cherche les images du project
function find_images {

    Param(
      [string]$images_name
    )

	# Recherche l'image en cours dans le dossier ou elles sont stockées
    $images_path_temp=Get-ChildItem -Path "$gns3_images_path_local" -Recurse | where {$_ -match "^$($images_name)$"}

    if ( "$images_path_temp" -eq ""  ) {
        affiche_error "Images $images_name introuvable dans le repertoire $gns3_images_path_local !"
        delete_temp
    }

	# Selection du chemin de l'image
    $images_path=$images_path_temp.PSPath | % {$_.split('::')[2] + ":" + $_.split('::')[3]}

    return $images_path
}

# Fonction qui execute une commande ssh sur la VM GNS3
function ssh_command {

    Param(
      [string]$command
    )

	# Commande SSH avec Putty
    plink.exe -pw "$pass_gns3_vm" "$user_gns3_vm@$ip_vm_gns3" "$command" | Out-Null 

    if ( $? -eq 0 ) {
        affiche_error "Commande $command a echoue sur l hote $ip_vm_gns3 avec l utilisateur $user_gns3_vm !"
        delete_temp
    }
}

# Fonction qui copie des fichiers en ssh de la VM GNS3 vers le repertoire temporaire
function ssh_copie {

    Param(
      [string]$source,
      [string]$dest
    )

	# Commande scp avec Putty
    pscp.exe -pw "$pass_gns3_vm" -r "$user_gns3_vm@$($ip_vm_gns3):$source" "$dest" | Out-Null

    if ( $? -eq 0 ) {
        affiche_error "La copie des fichiers $source vers $dest a echoue !"
        delete_temp
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

    Remove-Item -Force -Recurse $temp_path
    pause ; exit

}

write-output "###########################################################################"
write-output "################## Script d exportation des projets GNS3 ##################"
write-output "###########################################################################"

# Vérification des paramètres
verify-param

# Choix du project GNS3 à exporter

Write-Host "Liste des projects GNS3 :" -ForegroundColor Green
Write-Host ""

# Liste les projets GNS3 du repertoire gns3_proj_path_local
$compteur=0
# Affichage de tous les dossiers contenant un fichier de configuration GNS3
Get-ChildItem $gns3_proj_path_local | select Name | foreach { 
    if (Test-Path "$gns3_proj_path_local\$($_.name)\$($_.name).gns3") {
        $compteur=$compteur+1
        Write-Host "$compteur." $_.name
    }
}

# Quite le script si aucun projet dans le dossier indiqué
if ($compteur -eq 0) {
    affiche_error "Aucun projet à exporter !"
    delete_temp
}

# Tant qu'aucun projet n'est selectionné
do {
    Write-Host ""
    $num_project=$(Read-Host "Quel project ")
    $num_project=[int]$num_project
} while ( ($num_project -eq "") -or ($num_project -gt $compteur) )

# Récuperation du nom du projet en fonction du numero du projet selectionné
$compteur=0
Get-ChildItem $gns3_proj_path_local | foreach { 
    if (Test-Path "$gns3_proj_path_local\$($_.name)\$($_.name).gns3") {
        $compteur=$compteur+1
        if ( $compteur -like $num_project ) {
            $nom_project=$_.Name
            return
        }
    }
}

Write-Host "Projet $nom_project selectionne !" -ForegroundColor Green

# Copie du project dans le répertoire temporaire

Copy-Item -Recurse -Force -Path "$gns3_proj_path_local\$nom_project" -Destination "$temp_path"

if ( $? -eq 0 ) {
    affiche_error "Copie du projet $nom_project echoue !"
    delete_temp
}

Write-Host ""
Write-Host "Copie du projet $nom_project reussi dans $temp_path\$nom_project !" -ForegroundColor Green

# Recuperation du contenu au format JSON du fichier de configuration du projet GNS3
$project_file=Get-Content "$temp_path\$nom_project\$nom_project.gns3" | ConvertFrom-Json

# Selection des noeuds qui correspondent à des VM VMWARE et VBOX
$vm_project=$($project_file.topology.nodes) | where {$_.node_type -match "vmware" -or $_.node_type -match "virtualbox"}

# Selection des noeuds
$image_project=$($project_file.topology.nodes) | where {$_.node_type -match "qemu" -or $_.node_type -match "iou" -or $_.node_type -match "dynamips" -or $_.node_type -match "docker"}

Write-Host "      *  L ID du projet : $($project_file.project_id)"

# Vérification des paramètres des vms
# Si le projet inclut des VMs
if ($vm_project -ne $null) {
    verify-param-vm
}

# Vérification si la place est suffisante sur le disque seulement pour les VM Vmware et Vbox
if ($vm_project -ne $null) {
    check_space
}

# Vérification de l'existance du projet sur la VM
ssh_command "cd $gns3_proj_path_vm/$($project_file.project_id)" 

# Récuperation des données du project de la vm gns3
ssh_copie "$gns3_proj_path_vm/$($project_file.project_id)/project-files" "$temp_path\$nom_project"

Write-Host ""
Write-Host "Copie des fichiers du project $nom_project reussi dans $temp_path\$nom_project\project-files !" -ForegroundColor Green

# Si les Images doivent être incluse au projet
if ( ($IncludeImages -eq $true) -and ($image_project -ne $null) ) {

    # Creation de l'arborescence pour stocker les images dans le project
    # Création du dossier images du projet
    New-Item -ItemType Directory -Force -Path $temp_path\$nom_project\images | out-null

    if ( $? -eq 0 ) {
        affiche_error "Creation du repertoire $temp_path\$nom_project\images echoue !"
        delete_temp
    }
    # Création des dossiers correspondant à chaque type d'images
    foreach ($nodes in "QEMU","IOU","IOS","docker") {

        New-Item -ItemType Directory -Force -Path $temp_path\$nom_project\images\$nodes | out-null

        if ( $? -eq 0 ) {
            affiche_error "Creation du dossier $temp_path\$nom_project\images\$nodes echoue !"
            delete_temp
        }
    }

    # Export des images du project

    foreach ($images in $image_project) {

        # Export des images QEMU dans le repertoire temporaire du projet
        if ($($images.node_type) -match "qemu") {

		    # Export de chaque disque dur de la VM QEMU
            foreach ($lettre in "a","b","c","d") {

                $image_file_name="$($images.properties | select -ExpandProperty hd$($lettre)_disk_image)"
            
                if ( ! ("$image_file_name" -eq "") ) {
				
				    # Vérifie si le dique dur à déjà été copié
                    if ( $(verify_images "$image_file_name" "QEMU") ) {continue}
                    $images_path_local=find_images "$image_file_name"
                    copie-images "$images_path_local" "QEMU" "$image_file_name"
                } else {
                    continue
                } 
            }
            continue
        }

        # Export des images IOU dans le repertoire temporaire du projet
        elseif ($($images.node_type) -match "iou") {
        
		    # Vérifie si l'image à déjà été copié
            $image_file_name="$($images.properties.path)"
            if ( $(verify_images "$image_file_name" "IOU") ) {continue}
		
		    # Copie l'image IOU dans le dossier temporaire
            $images_path_local=find_images "$image_file_name"
            copie-images "$images_path_local" "IOU" "$image_file_name"
            continue
        }

        # Export des images DOCKER dans le repertoire temporaire du projet
        elseif ($($images.node_type) -match "docker") {

		    # Suppression des caractères "/" et ":" dans le nom des images docker
            if ($($images.properties.image) -match "/") {
                $container_name=$($images.properties.image).split('/')[1]
            } else {
                $container_name=$($images.properties.image)
            }
            if ($($images.properties.image) -match ":") {
                $container_name=$container_name.split(':')[0]
            }
        		
		    # Vérifie si l'image à déjà été copié
            if ( $(verify_images "$container_name" "docker") ) {continue}
		
            Write-Host ""
            Write-Host "Copie du container $container_name en cours !" -ForegroundColor Green

		    # Export l'image docker dans le dossier temporaire
            ssh_command "docker save $($images.properties.image) > /tmp/$container_name.tar"
            ssh_copie "/tmp/$container_name.tar" "$temp_path\$nom_project\images\docker\$container_name.tar"

            continue
        }

        # Export des images IOS dans le repertoire temporaire du projet
        elseif ($($images.node_type) -match "dynamips") {
        
		    # Vérifie si l'image à déjà été copié
            $image_file_name="$($images.properties.image)"
            if ( $(verify_images "$image_file_name" "IOS") ) {continue}
		
		    # Copie l'image IOU dans le dossier temporaire
            $images_path_local=find_images "$image_file_name"
            copie-images "$images_path_local" "IOS" "$image_file_name"
            continue
        }   

    }

    Write-Host ""
    Write-Host "Export des images dans $temp_path\$nom_project\images terminee avec succes !" -ForegroundColor Green

}
# Export des vms du project en ovf
# Si le projet inclut des VMs

if ($vm_project -ne $null) {

    foreach ($vm in $($vm_project)) {

        Write-Host ""
        Write-Host "Export de la VM $($vm.name) en cours :" -ForegroundColor Green
        Write-Host ""

	    # Export des vm vmware dans le repertoire temporaire
        if ($($vm.node_type) -match "vmware") {
	
		    # Export des VMs dans le dossier temporaire du script
		    Invoke-Command {& $($vmware_path_ovftool) --compress=9 "$($vm.properties.vmx_path)" "$temp_path"
            if ( $? -eq 0 ) {
                affiche_error "Export de la VM $($vm.name) echoue !"
                delete_temp
            }
            }
	
	    }

	    # Export des vm vbox dans le repertoire temporaire
	    elseif ($($vm.node_type) -match "virtualbox") {
	
		    $vm_path_source="$($vm.properties.vmname)"
		    $vm_path_dest="$temp_path\$($vm.properties.vmname)\$($vm.properties.vmname).ovf"
		    New-Item -ItemType Directory -Force -Path "$temp_path\$($vm.properties.vmname)" | Out-Null

		    # Export des VMs dans le dossier temporaire du script
		    Invoke-Command {& $($vbox_path_ovftool) export "$vm_path_source" -o "$vm_path_dest"
            if ( $? -eq 0 ) {
                affiche_error "Export de la VM $($vm.name) echoue !"
                delete_temp
            }
            }
	
	    }
    }

    # if ("$($vm.properties.use_any_adapter)" -match "false") {

        #Backup du fichier du fichier de configuration du projet GNS3

        # Copy-Item -Force -Path "$temp_path\$nom_project\$nom_project.gns3" -Destination "$temp_path\$nom_project\$nom_project.gns3.back"

        # if ( $? -eq 0 ) {
            # affiche_error "Copie du fichier gns3 du projet $temp_path\$nom_project\$nom_project.gns3 echoue !"
            # delete_temp
        # }

        #Changement du repertoire des vm dans le fichier GNS3 du projet

        # $new_gns3_content=Get-Content "$temp_path\$nom_project\$nom_project.gns3.back" | ForEach-Object {$_.replace('"use_any_adapter": false','"use_any_adapter": true')}

        # if ( $? -eq 0 ) {
            # affiche_error "Changement du parametre use_any_adapter dans le fichier de configuration de GNS3 echoue !"
            # delete_temp
        # }

        #Creation du nouveau fichier de configuration de GNS3 avec le nouveau chemin des VMs
        # [System.IO.File]::WriteAllLines("$temp_path\$nom_project\$nom_project.gns3", "$new_gns3_content")

        # Write-Host ""
        # Write-Host "Changement du parametre use_any_adapter dans le fichier de configuration de GNS3 terminee avec succes !" -ForegroundColor Green

    # }

    Write-Host ""
    Write-Host "Export des VMs dans $temp_path terminee avec succes !" -ForegroundColor Green

}

# Compression du project

Write-Host ""
Write-Host "Compression de $nom_project en cours :" -ForegroundColor Green

# Creation du zip pour les autres versions de powershell
if (Test-Path "$export_project_path\$nom_project.zip") {
    Remove-Item -Path "$export_project_path\$nom_project.zip"
}
# Export du projet en ZIP avec une compression Optimal
Add-Type -Assembly System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory("$temp_path\", "$export_project_path\$nom_project.zip", "Optimal", $false)


if ( $? -eq 0 ) {
        affiche_error "Compression du projet $nom_project echoue !"
        delete_temp
}

Write-Host ""
Write-Host "Compression de $nom_project reussi dans $export_project_path\$nom_project !" -ForegroundColor Green

# Vidage des fichiers temporaire
delete_temp

Write-Host ""
Write-Host "Script termine avec succes !" -ForegroundColor Green