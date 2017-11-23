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
    Inclut par défaut les Vms et les images avec le projet :
	> ./Nom du script

.EXAMPLE
    Pour lancer le script et définir les variables en ligne de commande sans modifier le script :
	> ./Nom du script -ProjectPath "Path" -ImagesPath "Path" -ProjectZip "Path" -IPGns3vm "Ip de la VM GNS3" -VmwareVmFolder "Path" -TmpPath "Path"

.INPUTS
   Pas d'entrée en pipe possible

.LINK
    https://github.com/FabienMht/GNS3_Project_Import_Export
 
.NOTES
    NAME            : Import projets GNS3
    AUTHOR          : Fabien Mauhourat
    Version GNS3    : 2.0.3
	Tester sur      : Windows 10
	
    VERSION HISTORY:

    1.0     2017.09.12   Fabien MAUHOURAT	Initial Version
    1.1     2017.09.28   Fabien MAUHOURAT   Ajout de la compatibilité Vbox et de la fonction de calcul de l'espace disque
    2.0     2017.11.19   Fabien MAUHOURAT   Ajout de la GUI et correction de BUGs changement d'adaptateur et export import de VM Vbox '
                                            et amélioration export de container docker et telechargement automatique de putty
                                            Possibilité d'importer des projets soit au format zip soit sans compression
	2.1     2017.11.23   Fabien MAUHOURAT	Correction de BUGs
	
#>

# Définition des variables
# Le dossier d'installation de Putty doit etre dans la variable PATH

[cmdletbinding()]
param (

	# Variables à changer
    [Parameter(Mandatory=$false, Position=1)]
    [Alias("ProjectPath")]
    [string]$gns3_proj_path_local="C:\Users\$env:UserName\GNS3\projects",
	
	[Parameter(Mandatory=$false, Position=2)]
    [Alias("ImagesPath")]
    [string]$gns3_images_path_local="C:\Users\$env:UserName\GNS3\images",

    [Parameter(Mandatory=$false, Position=3)]
    [Alias("ProjectZip")]
    [string]$gns3_proj_path_src="C:\Users\$env:UserName\Desktop",

    [Parameter(Mandatory=$false, Position=4)]
    [Alias("IPGns3vm")]
    [string]$ip_vm_gns3="",

	# Le chemin absolue des VM doit etre séparé par des doubles "\\"
    [Parameter(Mandatory=$false, Position=5)]
    [Alias("VmwareVmFolder")]
    [string]$vmware_path_vm_folder="C:\\Users\\$env:UserName\\Documents\\Virtual Machines",
	
	[Parameter(Mandatory=$false, Position=6)]
    [Alias("TmpPath")]
    [string]$temp_path="C:\Temp",
	
	# Variable par défaut
    [string]$gns3_images_path_vm="/opt/gns3/images",
	[string]$gns3_projects_path_vm="/opt/gns3/projects",
    [string]$pass_gns3_vm="gns3",
    [string]$user_gns3_vm="gns3",
    [string]$vmware_path_ovftool="C:\Program Files (x86)\VMware\VMware Workstation",
    [string]$vbox_path_ovftool="C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
	[string]$putty_path="",
	[string]$script_name=$MyInvocation.MyCommand.Name

)

# Fonction qui verifie les paramètres du script
function verify-param {

	# Vérifie si la vm GNS3 est joingnable et si les chemins existent
    if ( ! (ping $ip_vm_gns3 -n 2 | Select-String "TTL=") ) {
        affiche_error "La vm GNS3 $ip_vm_gns3 n est pas accessible !"
        exit
    }
    if ( $gns3_proj_path_local -eq "" -or ! (Test-Path $gns3_proj_path_local) ) {
        affiche_error "La variable gns3_proj_path_local n est pas definie !"
        exit
    }
	if ( $gns3_images_path_local -eq "" -or ! (Test-Path $gns3_images_path_local) ) {
        affiche_error "La variable gns3_images_path_local n est pas definie !"
        exit
    }
    if ( $gns3_proj_path_src -eq "" -or ! (Test-Path $gns3_proj_path_src) ) {
        affiche_error "La variable gns3_proj_path_src n est pas definie !"
        exit
    }
	
	# Vérifie si les variables sont nulles
    if ( $temp_path -eq "" ) {
        affiche_error "La variable temp_path n est pas definie !"
        exit
    }
    if ( $pass_gns3_vm -eq "" ) {
        affiche_error "La variable pass_gns3_vm n est pas definie !"
        exit
    }
    if ( $user_gns3_vm -eq "" ) {
        affiche_error "La variable user_gns3_vm n est pas definie !"
        exit
    }
    if ( $gns3_images_path_vm -eq "" ) {
        affiche_error "La variable gns3_images_path_vm n est pas definie !"
        exit
    }
	if ( $gns3_projects_path_vm -eq "" ) {
        affiche_error "La variable gns3_projects_path_vm n est pas definie !"
        exit
    }
	
	# Supprime le répertoire temporaire s'il existe
    if (Test-Path "$temp_path\") {
        Remove-Item -Force -Recurse "$temp_path\*"
        if ( $? -eq 0 ) {
            affiche_error "Creation du dossier GNS3-TEMP dans $temp_path echoue !"
            exit
        }
    }
	
	# Crée le repertoire de travail temporaire
	New-Item -ItemType Directory -Force -Path "$temp_path\" | Out-Null
    if ( $? -eq 0 ) {
        affiche_error "Creation du dossier GNS3-TEMP dans $temp_path echoue !"
        exit
    }
	
	# Verifie si Putty est installé
	if ( ( ! (Invoke-Command {& plink})) -or ( ! (Invoke-Command {& pscp})) ) {
		
		Write-Host ""
		Write-Host "Telechargement du client SSH Putty ...." -ForegroundColor Green
	
		# Téléchargement de putty dans le repertoire temporaire
		$url = "https://the.earth.li/~sgtatham/putty/latest/w32/putty.zip"
		$output = "$temp_path\putty.zip"
		$start_time = Get-Date

		(New-Object System.Net.WebClient).DownloadFile($url, $output)
		
		# Décompresson pour les autres versions de Powershell
		Add-Type -Assembly "System.IO.Compression.FileSystem"
		[System.IO.Compression.ZipFile]::ExtractToDirectory("$temp_path\putty.zip", "$temp_path\putty")
			
		if ( $? -eq 0 ) {
			affiche_error "Putty n'est pas installe sur le poste ou le chemin n est pas dans la variable PATH !"
			Remove-Item -Force -Recurse "$temp_path\*" | Out-Null
			exit
        }
		
		Remove-Item -Force "$output"
		$script:putty_path="$temp_path\putty\"
		
		Write-Host ""
		Write-host "Telechargement de Putty termine: $((Get-Date).Subtract($start_time).Seconds) second(s)" -ForegroundColor Green

    }

	# Affiche un recap de la configuration en cours
	Write-Host ""
	Write-Host "############ Script commencé à $(Get-Date -format 'HH:mm:ss') ############"
    Write-Host ""
    Write-Host "1. Verification des parametres terminee sans erreurs :" -ForegroundColor Green
    Write-Host ""
    Write-Host "La configuration est la suivante :"
    Write-Host "     * Repertoire temporaire : $temp_path"
    Write-Host "     * Chemin projects : $gns3_proj_path_local"
    Write-Host "     * Chemin images : $gns3_images_path_local"
    Write-Host "     * IpVM GNS3 : $ip_vm_gns3"
	Write-Host "     * Chemin des VMs : $vmware_path_vm_folder"
	Write-Host ""
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

            0..($split_path.Length - 1) | Foreach-Object {

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
            $script:path_disk_vbox=(Invoke-Command {& $vbox_path_ovftool list systemproperties} | Where-Object {$_ -match "Default machine folder"}).replace('Default machine folder:          ','')
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
		Write-Host "Temps estime d export du projet : $("{0:N2}" -f ($project_size * 18 / 9.2 / 60)) H !"
		
        $msgBoxInput = [System.Windows.Forms.Messagebox]::Show("Il restera moins de $size_after_import GB sur le disque ! Continuer ?",'Espace Disque','YesNo','Warning')

		switch ($msgBoxInput) {

			'No' {
				affiche_error "La taille du disque est insuffisante pour importer le projet : $("{0:N1}" -f ($project_size)) GB !"
				delete_temp "$temp_path"
			}
		}
    }
	
    # Continue le script si la taille du disque est suffisante
    else {
        Write-Host ""
        Write-Host "La taille du disque est suffisante après import : $size_after_import GB !"
        Write-Host "Taille du projet : $("{0:N1}" -f ($project_size)) GB !"
		Write-Host "Temps estime d export du projet : $("{0:N2}" -f ($project_size * 18 / 9.2 / 60)) H !"
    }

}

# Vérification si la place est suffisante sur le disque (taille des vms)
function check_space {
    
    Write-Host ""
    Write-Host "La taille du projet :" -ForegroundColor Green

    # Récuperation de la lettre des lecteurs
    $root_temp="$(($temp_path).Split(':')[0])"

    # Calcul de la taille restante du disque des fichiers temporaire
    $size_disk=(Get-PSDrive $root_temp | Select-Object -ExpandProperty Free) / 1GB

    # Calcul de la taille du projet
	if ( $zip_projet -eq $true ) {
	
		$project_size=([System.IO.Compression.ZipFile]::OpenRead("$gns3_proj_path_src\$nom_project.zip").Entries | Measure-Object -property length -sum).Sum /1GB
	
	} else {
	
		$project_size=(Get-ChildItem -Recurse "$gns3_proj_path_src\$nom_project" | Where-Object { -not $_.PSIsContainer } | Measure-Object -property length -sum).Sum / 1GB
		
	}

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
                $size_disk=(Get-PSDrive "$disk" | Select-Object -ExpandProperty Free) / 1GB
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
                $size_disk=(Get-PSDrive "$disk" | Select-Object -ExpandProperty Free) / 1GB
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
    & "$($putty_path)pscp.exe" -pw $pass_gns3_vm -r "$source" "$user_gns3_vm@$($ip_vm_gns3):$dest" | Out-Null

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
    $ssh_return=$(& "$($putty_path)plink.exe" -pw "$pass_gns3_vm" "$user_gns3_vm@$ip_vm_gns3" "$command")

    if ( $? -eq 0 ) {
        affiche_error "Commande $command a echoue sur l hote $ip_vm_gns3 avec l utilisateur $user_gns3_vm !"
        delete_temp "$temp_path"
    }
	
	return $ssh_return
}

# Fonction qui affiche les erreurs du script
function affiche_error {
    
    Write-Host ""
    Write-Error "$args"
    Write-Host ""
	
	$statusBar.Text = "$args"
	$progress.Value = 0
	
	[System.Windows.Forms.Messagebox]::Show("$args",'Script d import','OK','Error')
}

# Fonction qui supprime les fichiers temporaires du script
function delete_temp {

    Param(
      [string]$path
    )

    Remove-Item -Force -Recurse "$path"
    exit

}

# Fonction qui affiche les erreurs du script
function affiche_projets {

	Write-Host ""
	Write-Host "Liste des projects GNS3 :" -ForegroundColor Green
	Write-Host ""

	$script:gns3_proj_path_src = $textbox_ExportPath.Text

	# Affichage de tous les dossiers contenant un fichier de configuration GNS3
	$cmb_Choix_Projets.Items.clear()
	$compteur=0
	
	Get-ChildItem $gns3_proj_path_src | Select-Object Name | Foreach-Object { 
		if ((Test-Path "$gns3_proj_path_src\$($_.name)\$($_.name)\$($_.name).gns3") -or ("$($_.name)" -match ".zip")) {
		
			if ("$($_.name)" -match ".zip") {
			
				$test_projet=[System.IO.Compression.ZipFile]::OpenRead("$gns3_proj_path_src\$($_.Name)").Entries | Where-Object Name -Like "*.gns3"
				
				if ( $test_projet -eq $null ) {
					continue
				}
			}
			
			$compteur=$compteur+1
			Write-Host "$compteur." $_.name
			$cmb_Choix_Projets.Items.Add($_.name) | Out-Null
		}
	}
}

function About {

    $statusBar.Text = "A Propos"
	
    # About Form Objects
    $aboutForm          = New-Object System.Windows.Forms.Form
    $aboutFormExit      = New-Object System.Windows.Forms.Button
    $aboutFormImage     = New-Object System.Windows.Forms.PictureBox
    $aboutFormNameLabel = New-Object System.Windows.Forms.Label
    $aboutFormText      = New-Object System.Windows.Forms.Label

    # About Form
    $aboutForm.AcceptButton  = $aboutFormExit
    $aboutForm.CancelButton  = $aboutFormExit
    $aboutForm.ClientSize    = "350, 135"
    $aboutForm.ControlBox    = $false
    $aboutForm.ShowInTaskBar = $false
    $aboutForm.StartPosition = "CenterParent"
    $aboutForm.Text          = "A Propos GNS3_Project_Import_Export"
    $aboutForm.Add_Load($aboutForm_Load)

    # About PictureBox
    $aboutFormImage.Image    = $iconPS.ToBitmap()
    $aboutFormImage.Location = "55, 15"
    $aboutFormImage.Size     = "32, 32"
    $aboutFormImage.SizeMode = "StretchImage"
    $aboutForm.Controls.Add($aboutFormImage)

    # About Name Label
    $aboutFormNameLabel.Font     = New-Object Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $aboutFormNameLabel.Location = "110, 20"
    $aboutFormNameLabel.Size     = "200, 35"
    $aboutFormNameLabel.Text     = "        Script d'exportation et `n`r d'importation de projets GNS3"
    $aboutForm.Controls.Add($aboutFormNameLabel)

    $aboutFormText.Location = "145, 55"
    $aboutFormText.Size     = "300, 40"
    $aboutFormText.Text     = "Fabien Mauhourat `n`r      Version 2.1 `n`r Licence GPLv3"
    $aboutForm.Controls.Add($aboutFormText)

    # About Exit Button
    $aboutFormExit.Location = "155, 100"
    $aboutFormExit.Text     = "OK"
    $aboutForm.Controls.Add($aboutFormExit)

    $aboutForm.ShowDialog()
	
    $statusBar.Text = "Prêt"
}

Write-Host "###########################################################################"
Write-Host "################## Script d Importation des projets GNS3 ##################"
Write-Host "###########################################################################"

#################################################
# Creation des objets de la fenetre
#################################################

# Chargement des Windows Form
Add-Type –AssemblyName System.Windows.Forms
[Windows.Forms.Application]::EnableVisualStyles()    
Add-Type -assembly "system.io.compression.filesystem" 
$host.ui.RawUI.WindowTitle = "Import de projet GNS3 v2.1 Fabien Mauhourat"

# Définission des objets de la fenetre
$form = New-Object System.Windows.Forms.Form
# Extract PowerShell Icon from PowerShell Exe
$iconPS   = [Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Path)

# Définision des buttons
$button_Export 		= New-Object System.Windows.Forms.Button
$button_Cancel 		= New-Object System.Windows.Forms.Button
$button_quit 		= New-Object System.Windows.Forms.Button
$button_ProjetPath 	= New-Object System.Windows.Forms.Button
$button_ImagesPath 	= New-Object System.Windows.Forms.Button
$button_TmpPath 	= New-Object System.Windows.Forms.Button
$button_ExportPath 	= New-Object System.Windows.Forms.Button
$button_VMPath 		= New-Object System.Windows.Forms.Button
$button_IPPing 		= New-Object System.Windows.Forms.Button

# Définission des textboxs
$textbox_ProjetPath 	= New-Object System.Windows.Forms.TextBox
$textbox_ImagesPath 	= New-Object System.Windows.Forms.TextBox
$textbox_TmpPath 		= New-Object System.Windows.Forms.TextBox
$textbox_ExportPath 	= New-Object System.Windows.Forms.TextBox
$textbox_VMPath 		= New-Object System.Windows.Forms.TextBox
$textbox_IPGns3vm 		= New-Object System.Windows.Forms.TextBox

# Définission des Labels
$label_title 		= New-Object System.Windows.Forms.Label
$label_ProjetPath 	= New-Object System.Windows.Forms.Label
$label_ImagesPath 	= New-Object System.Windows.Forms.Label
$label_TmpPath 		= New-Object System.Windows.Forms.Label
$label_ExportPath 	= New-Object System.Windows.Forms.Label
$label_VMPath 		= New-Object System.Windows.Forms.Label
$label_IPGns3vm 	= New-Object System.Windows.Forms.Label
$label_progressbar 	= New-Object System.Windows.Forms.Label

# Définission des groupbox
$choix_options 	= New-Object System.Windows.Forms.GroupBox
$choix_projets	= New-Object System.Windows.Forms.GroupBox

# Définission des Barres d'information d'avancement du script
$statusBar 	= New-Object System.Windows.Forms.StatusBar
$progress 	= New-Object System.Windows.Forms.ProgressBar

# Définission des ComboBox
$cmb_Choix_Projets 	= New-Object System.Windows.Forms.ComboBox
$openFolderDialog 	= New-Object System.Windows.Forms.FolderBrowserDialog

# Menu
$menuMain    = New-Object System.Windows.Forms.MenuStrip
$menuFile    = New-Object System.Windows.Forms.ToolStripMenuItem
$menuExit    = New-Object System.Windows.Forms.ToolStripMenuItem
$menuHelp    = New-Object System.Windows.Forms.ToolStripMenuItem
$menuAbout   = New-Object System.Windows.Forms.ToolStripMenuItem
$menuDoc	 = New-Object System.Windows.Forms.ToolStripMenuItem
$menuOnline  = New-Object System.Windows.Forms.ToolStripMenuItem

#################################################
# CONFIGURATION DE LA WINDOWS FORM
#################################################

# Creation de la form principale
$form.FormBorderStyle = 1
$form.MaximizeBox = $False
$form.MinimizeBox = $False
$form.Icon = $iconPS
$form.Text = "Import de projet GNS3 v2.1 Fabien Mauhourat"
$form.StartPosition= 1
$form.Size = New-Object System.Drawing.Size(540,750)
$form.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,13,0,2,1)

#################################################
# AJOUT DES COMPOSANTS
#################################################

# Bouton monter
$button_Export.Text = "Importer Projet"
$button_Export.Size = New-Object System.Drawing.Size(390,40)
$button_Export.Location = New-Object System.Drawing.Size(65,575)

# Bouton dem
$button_Cancel.Text = "Demonter l'image !"
$button_Cancel.Size = New-Object System.Drawing.Size(185,40)
$button_Cancel.Location = New-Object System.Drawing.Size(270,575)

# Bouton Quitter
$button_quit.Text = "Fermer"
$button_quit.Size = New-Object System.Drawing.Size(390,40)
$button_quit.Location = New-Object System.Drawing.Size(65,625)

# Bouton ProjetPath
$button_ProjetPath.Text = "..."
$button_ProjetPath.Size = New-Object System.Drawing.Size(25,27)
$button_ProjetPath.Location = New-Object System.Drawing.Size(430,47)

# Bouton ImagesPath
$button_ImagesPath.Text = "..."
$button_ImagesPath.Size = New-Object System.Drawing.Size(25,27)
$button_ImagesPath.Location = New-Object System.Drawing.Size(430,97)

# Bouton TmpPath
$button_TmpPath.Text = "..."
$button_TmpPath.Size = New-Object System.Drawing.Size(25,27)
$button_TmpPath.Location = New-Object System.Drawing.Size(430,147)

# Bouton ExportPath
$button_ExportPath.Text = "..."
$button_ExportPath.Size = New-Object System.Drawing.Size(25,27)
$button_ExportPath.Location = New-Object System.Drawing.Size(430,197)

# Bouton VMPath
$button_VMPath.Text = "..."
$button_VMPath.Size = New-Object System.Drawing.Size(25,27)
$button_VMPath.Location = New-Object System.Drawing.Size(430,247)

# Bouton Ping
$button_IPPing.Text = "Ping"
$button_IPPing.Size = New-Object System.Drawing.Size(40,27)
$button_IPPing.Location = New-Object System.Drawing.Size(422,297)

# Label title
$label_title.Location = New-Object System.Drawing.Point(170,40)
$label_title.Size = New-Object System.Drawing.Size(380,35)
$label_title.Text = "Import Projets Gns3"
$label_title.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,16,1,2,1)
$label_title.TabIndex = 1

# TextBox ProjetPath
$textbox_ProjetPath.AutoSize = $true
$textbox_ProjetPath.Location = New-Object System.Drawing.Point(20,50)
$textbox_ProjetPath.Size = New-Object System.Drawing.Size(390,25)
$textbox_ProjetPath.Text = $gns3_proj_path_local

# TextBox ImagesPath
$textbox_ImagesPath.AutoSize = $true
$textbox_ImagesPath.Location = New-Object System.Drawing.Point(20,100)
$textbox_ImagesPath.Size = New-Object System.Drawing.Size(390,10)
$textbox_ImagesPath.Text = $gns3_images_path_local

# TextBox TmpPath
$textbox_TmpPath.AutoSize = $true
$textbox_TmpPath.Location = New-Object System.Drawing.Point(20,150)
$textbox_TmpPath.Size = New-Object System.Drawing.Size(390,50)
$textbox_TmpPath.Text = $temp_path

# TextBox ExportPath
$textbox_ExportPath.AutoSize = $true
$textbox_ExportPath.Location = New-Object System.Drawing.Point(20,200)
$textbox_ExportPath.Size = New-Object System.Drawing.Size(390,50)
$textbox_ExportPath.Text = $gns3_proj_path_src
# $textbox_ExportPath.Text = "C:\Temp"

# TextBox VMPath
$textbox_VMPath.AutoSize = $true
$textbox_VMPath.Location = New-Object System.Drawing.Point(20,250)
$textbox_VMPath.Size = New-Object System.Drawing.Size(390,50)
$textbox_VMPath.Text = $vmware_path_vm_folder

# TextBox IPGns3vm
$textbox_IPGns3vm.AutoSize = $true
$textbox_IPGns3vm.Location = New-Object System.Drawing.Point(20,300)
$textbox_IPGns3vm.Size = New-Object System.Drawing.Size(390,50)
$textbox_IPGns3vm.Text = $ip_vm_gns3

# Label ProjetPath
$label_ProjetPath.AutoSize = $true
$label_ProjetPath.Location = New-Object System.Drawing.Point(20,30)
$label_ProjetPath.Text = "Chemin Projets Gns3 :"

# Label ImagesPath
$label_ImagesPath.AutoSize = $true
$label_ImagesPath.Location = New-Object System.Drawing.Point(20,80)
$label_ImagesPath.Text = "Chemin Images Gns3 :"

# Label TmpPath
$label_TmpPath.AutoSize = $true
$label_TmpPath.Location = New-Object System.Drawing.Point(20,130)
$label_TmpPath.Text = "Dossier Temporaire :"

# Label ExportPath
$label_ExportPath.AutoSize = $true
$label_ExportPath.Location = New-Object System.Drawing.Point(20,180)
$label_ExportPath.Text = "Dossier source des projets :"

# Label VMPath
$label_VMPath.AutoSize = $true
$label_VMPath.Location = New-Object System.Drawing.Point(20,230)
$label_VMPath.Text = "Dossier des VMs (Uniquement Vmware) :"

# Label IPGns3vm
$label_IPGns3vm.AutoSize = $true
$label_IPGns3vm.Location = New-Object System.Drawing.Point(20,280)
$label_IPGns3vm.Text = "Ip VM GNS3 :"

# Label progressbar
$label_progressbar.AutoSize = $true
$label_progressbar.Location = New-Object System.Drawing.Point(65,515)
$label_progressbar.Text = "3. L'avancement :"

# Barre de status
$statusBar.DataBindings.DefaultDataSourceUpdateMode = 0
$statusBar.Location = New-Object System.Drawing.Point(0,680)
$statusBar.Name = “statusBar”
$statusBar.Size = New-Object System.Drawing.Size(440,23)
$statusBar.Text = "Prêt"
$statusBar.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,14,0,2,1)

# Barre de progression
$progress.Location = New-Object System.Drawing.Point(65,540)
$progress.Size = New-Object System.Drawing.Size(390,23)

# Boite de dialogue
$openFolderDialog.RootFolder       = "Desktop"
$openFolderDialog.Description      = "Selectionner le dossier de destination"
$openFolderDialog.SelectedPath     = $WorkingDirectory
	
# ComboBox qui affiche les projets
$cmb_Choix_Projets.DataBindings.DefaultDataSourceUpdateMode = 0
$cmb_Choix_Projets.AutoSize = 1
$cmb_Choix_Projets.FormattingEnabled = $True
$cmb_Choix_Projets.Location        = New-Object System.Drawing.Point(20,22)
$cmb_Choix_Projets.Name            = "cmb_Choix_Projets"
$cmb_Choix_Projets.Size            = New-Object System.Drawing.Size(390,20)
$cmb_Choix_Projets.TabIndex        = 0

############# Groupe de radio bouton Choix de la configuration ################

$choix_options.DataBindings.DefaultDataSourceUpdateMode = 0
$choix_options.Location = New-Object System.Drawing.Point(20,80)
$choix_options.Size = New-Object System.Drawing.Size(480,345)
$choix_options.TabIndex = 1
$choix_options.TabStop = $False
$choix_options.Text = “1. Options de configuration”
$choix_options.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,13,0,2,1)

$choix_options.Controls.Add($textbox_ProjetPath)
$choix_options.Controls.Add($textbox_ImagesPath)
$choix_options.Controls.Add($textbox_TmpPath)
$choix_options.Controls.Add($textbox_ExportPath)
$choix_options.Controls.Add($textbox_VMPath)
$choix_options.Controls.Add($textbox_IPGns3vm)
$choix_options.Controls.Add($button_ProjetPath)
$choix_options.Controls.Add($button_ImagesPath)
$choix_options.Controls.Add($button_TmpPath)
$choix_options.Controls.Add($button_ExportPath)
$choix_options.Controls.Add($button_VMPath)
$choix_options.Controls.Add($button_IPPing)
$choix_options.Controls.Add($label_ProjetPath)
$choix_options.Controls.Add($label_ImagesPath)
$choix_options.Controls.Add($label_IPGns3vm)
$choix_options.Controls.Add($label_TmpPath)
$choix_options.Controls.Add($label_ExportPath)
$choix_options.Controls.Add($label_VMPath)

############# Groupe de radio bouton Choix du projet ################

$choix_projets.DataBindings.DefaultDataSourceUpdateMode = 0
$choix_projets.Location = New-Object System.Drawing.Point(20,435)
$choix_projets.Size = New-Object System.Drawing.Size(480,60)
$choix_projets.TabIndex = 2
$choix_projets.TabStop = $False
$choix_projets.Text = “2. Choisir Projet :”
$choix_projets.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,13,0,2,1)

$choix_projets.Controls.Add($cmb_Choix_Projets)

# Appel de la fonction qui affiche les projets
affiche_projets

#################### Main Menu ######################

# Main Menu Bar
$form.Controls.Add($menuMain)

# Menu Options - Fichier
$menuFile.Text = "&Fichier"
[void]$menuMain.Items.Add($menuFile)

# Menu Options - Fichier / Quitter
$menuExit.ShortcutKeys = "Control, Q"
$menuExit.Text = "&Quitter"
$menuExit.Add_Click({$form.Close()})
[void]$menuFile.DropDownItems.Add($menuExit)

# Menu Options - Aide
$menuHelp.Text      = "&Aide"
[void]$menuMain.Items.Add($menuHelp)

# Menu Options - Aide / Documentation
$menuDoc.Image     = [System.Drawing.SystemIcons]::Information
$menuDoc.Text      = "Documentation Script"

$menuDoc.Add_Click({
	write-host "Aide script d Import :" -ForegroundColor Green
	Get-Help "$PSScriptRoot\$script_name" | out-host
})
[void]$menuHelp.DropDownItems.Add($menuDoc)

# Menu Options - Aide / Documentation
$menuOnline.Image     = [System.Drawing.SystemIcons]::Information
$menuOnline.Text      = "Documentation en ligne"

$menuOnline.Add_Click({
	Start-Process https://github.com/FabienMht/GNS3_Project_Import_Export
})
[void]$menuHelp.DropDownItems.Add($menuOnline)

# Menu Options - Aide / A propos
$menuAbout.Image     = [System.Drawing.SystemIcons]::Information
$menuAbout.Text      = "A propos de GNS3-Import-Export"
$menuAbout.Add_Click({About})
[void]$menuHelp.DropDownItems.Add($menuAbout)

##########################################################
############## GESTION DES EVENEMENTS ####################

# Gestion event quand on clique sur le bouton Fermer
$button_quit.Add_Click(
{
	$form.Close();
})

# Gestion event quand on clique sur le bouton Ping
$button_IPPing.Add_Click(
{
	$statusBar.Text = "Test de connexion à la VM GNS3"
	
	# Vérifie si la vm GNS3 est joingnable et si les chemins existent
    if ( ! (ping $textbox_IPGns3vm.Text -n 2 | Select-String "TTL=") ) {
        affiche_error "La vm GNS3 $ip_vm_gns3 n est pas accessible !"
        exit
    }
	
	[System.Windows.Forms.Messagebox]::Show('La VM GNS3 est Joignable !','VM GNS3','OK','Info')
	
	$statusBar.Text = "Prêt"
})

# Gestion event quand on clique sur le bouton OK
$button_Export.Add_Click(
{
    $progress.Value = 0
	$statusBar.Text = "Importation"
	$start_time_script = Get-Date
	
	#Déclaration des variables
	if ( ! $cmb_Choix_Projets.SelectedItem ) {
		affiche_error "Aucun projet selectionné !"
		exit
	}
	
	$nom_project=$($cmb_Choix_Projets.SelectedItem.ToString())
	
	if ("$nom_project" -match ".zip") {
		$zip_projet=$true
	}
	
	$gns3_proj_path_local=$textbox_ProjetPath.Text
	$gns3_images_path_local=$textbox_ImagesPath.Text
	$ip_vm_gns3=$textbox_IPGns3vm.Text
	$temp_path="$($textbox_TmpPath.Text)\GNS3-TEMP"
	$gns3_proj_path_src=$textbox_ExportPath.Text
	$vmware_path_vm_folder=$textbox_VMPath.Text
	
	# Vérification des paramètres
	$statusBar.Text = “Vérification des paramètres $($progress.Value) %”
	verify-param

	$nom_project=[System.IO.Path]::GetFileNameWithoutExtension("$nom_project")

	# Vérifie si le projet existe déjà sur le poste
	if ( Test-Path "$gns3_proj_path_local\$nom_project\$nom_project.gns3" ) {

		Write-Host ""
		Write-Warning "Le projet $nom_project existe deja sur le poste : $gns3_proj_path_local\$nom_project !"
		Write-Host ""

		$msgBoxInput = [System.Windows.Forms.Messagebox]::Show("Le projet $nom_project existe deja sur le poste ! Le Supprimer ?",'Projet','YesNo','Warning')

		switch ($msgBoxInput) {

			'Yes' {
				Remove-Item -Force -Recurse "$gns3_proj_path_local\$nom_project"
			}
			
			'No' {
				affiche_error "Le projet $nom_project existe deja sur le poste : $gns3_proj_path_local\$nom_project !"
				delete_temp "$temp_path"
			}

		}
	}
	
	Write-Host "Projet $nom_project selectionne !" -ForegroundColor Green

	$progress.Value = 5	
	$statusBar.Text = “Vérification de l espace disque et des paramètres des Vms $($progress.Value) %”
		
	if ( ! $zip_projet -eq $true ) {
			
		# Recuperation du contenu au format JSON du fichier de configuration du projet GNS3
		$project_file=Get-Content "$gns3_proj_path_src\$nom_project\$nom_project\$nom_project.gns3" | ConvertFrom-Json
		
	} else {
	
		# Récuperation du contenu du fichier de configuration de GNS3
		$project_conf=[System.IO.Compression.ZipFile]::OpenRead("$gns3_proj_path_src\$nom_project.zip").Entries | Where-Object name -Match "$nom_project.gns3"

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
	}
	
	$vm_vbox=$project_file.topology.nodes | Where-Object node_type -eq "virtualbox"
	$vm_vmware=$project_file.topology.nodes | Where-Object node_type -eq "vmware"

	# Vérification des paramètres pour les vms
	verify-param-vm

	# Vérifie si la taille du disque est suffisante
	check_space

	# Décompression ou copie du projet dans le repertoire temporaire
	if ( $zip_projet -eq $true ) {
	
		# Decompression du project
		Write-Host ""
		Write-Host "2. Decompression de $nom_project en cours :" -ForegroundColor Green

		$progress.Value = 10	
		$statusBar.Text = “2. Decompression du project $($progress.Value) %”
	
		# Décompression pour powershell 5 et anterieur
		if ((Get-Host | Select-Object -ExpandProperty Version | Select-Object -ExpandProperty major) -eq 5){

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
		Write-Host "2. Decompression de $nom_project reussi dans $temp_path\$nom_project !"

		# Recuperation du contenu au format JSON du fichier de configuration du projet GNS3
		$project_file=Get-Content "$temp_path\$nom_project\$nom_project.gns3" | ConvertFrom-Json

	} else {
	
		# Copie du project
		Write-Host ""
		Write-Host "2. Copie du projet $nom_project en cours :" -ForegroundColor Green
		
		$progress.Value = 10	
		$statusBar.Text = “2. Import du projet dans le répertoire temporaire $($progress.Value) %”
	
		# Copie du project dans le répertoire temporaire

		Copy-Item -Recurse -Force -Path "$gns3_proj_path_src\$nom_project\*" -Destination "$temp_path"

		if ( $? -eq 0 ) {
			affiche_error "Copie du projet $nom_project echoue !"
			delete_temp
		}
		
		Write-Host ""
		Write-Host "2. Copie du projet $nom_project reussi dans $temp_path\$nom_project !" -ForegroundColor Green
		
	}

	$imges_test=Get-ChildItem -Recurse "$temp_path\$nom_project\images" | where mode -NotMatch "^d"
	
	# Si le projet comporte des images
	if ("$imges_test" -ne "") {

		$progress.Value = 30
		$statusBar.Text = “3. Import des images du project $($progress.Value) %”
	
		# Import des images du project

		$images_path_folder=Get-ChildItem "$temp_path\$nom_project\images"

		# $folder_vm=$(& "$($putty_path)plink.exe" -pw "$pass_gns3_vm" "$user_gns3_vm@$ip_vm_gns3" "ls -l $gns3_images_path_vm | grep '^d'")
		$folder_vm=$(ssh_command "ls -l $gns3_images_path_vm | grep '^d'")

		# Creation des dossiers des images sur la VM GNS3
		foreach ($folder_name in "QEMU","IOU","IOS") {
			if ( ! ($folder_vm | Where-Object {$_ -match "$folder_name"}) ) {
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
				
					# $docker_images=$(& "$($putty_path)plink.exe" -pw "$pass_gns3_vm" "$user_gns3_vm@$ip_vm_gns3" "docker images | grep $images_ref_name_docker")
					# $docker_images=$(ssh_command "docker images | grep $images_ref_name_docker")

					# Pour les images docker
					# if ( "$docker_images" -ne "" ) {
						# Write-Host ""
						# Write-Host "L image $images_ref_name_docker existe deja sur la VM GNS3 !"
						# continue
					# }

					Write-Host ""
					Write-Host "Import de l image $images_ref_name_docker en cours ..."

					# Copie et importation de l'image sur la VM
					ssh_copie "$images_ref_path" "/tmp/$images_ref_name"
					ssh_command "docker load < /tmp/$images_ref_name"
					ssh_command "rm /tmp/$images_ref_name"
					
				}
				continue
			}

			$images_vm=ssh_command "ls $gns3_images_path_vm/$folder" | Where-Object {$_ -notmatch "md5sum"}

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
					$images_ref_path=$images_local.PSPath | Where-Object {$_ -match "$images_ref"} | ForEach-Object {$_.split('::')[2] + ":" + $_.split('::')[3]}

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
		Write-Host "3. Import des images dans $gns3_images_path_vm terminee avec succes !" -ForegroundColor Green
		
		Copy-Item -Recurse -Force -Exclude docker "$temp_path\$nom_project\images\*" "$gns3_images_path_local\"

	} else {
		Write-Host ""
		Write-Host "3. Aucune image associé au projet !" -ForegroundColor Green
	}
	
	# Import des vm du project en ovf

	$vm_path_temp=Get-ChildItem $temp_path -Recurse | Where-Object {$_ -match ".ovf$"}

	if ("$vm_path_temp" -ne "") {

		$progress.Value = 40	
		$statusBar.Text = “4. Import des vms du project en ovf $($progress.Value) %”
	
		Write-Host ""
		Write-Host "4. Import des VMs en cours :" -ForegroundColor Green

		# Récuperation des noms des vms vbox du projet
		$vm_vbox_test=$project_file.topology.nodes | Where-Object node_type -eq "virtualbox" | Select-Object -ExpandProperty properties | Select-Object -ExpandProperty vmname

		# Verifie si le projet utilise des vms vmware
		$vm_vmware_test=$project_file.topology.nodes | Where-Object node_type -eq "vmware"
		
		$vm_count=$($vm_path_temp | Measure-Object -Property name | Select-Object -ExpandProperty Count)
		$progress_count= 50 / $vm_count
		$progress_vm= 40
		$compteur_vms=0
		
		# Importation de toutes les VMs du projet dans le repertoire local des VMs
		foreach ($vm in $vm_path_temp) {
			
			# Récuperation du chemin des VMs du projet
			$vm_path=$vm.fullname
			$vm_name=$vm.directory.name

			$test_vbox=0
			$compteur_vms+=1
			Write-Host ""
			Write-Host "$compteur_vms/$vm_count Import de la VM $vm_name en cours :" -ForegroundColor Green
			Write-Host ""

			$statusBar.Text = "$compteur_vms/$vm_count Export de la VM $($vm.name) en cours $($progress.Value) %"
			$progress_vm= $progress_vm + $progress_count
			
			# Teste si la VM est une vm virtualbox
			foreach ($vm_vbox in $vm_vbox_test) {

				if ("$vm_vbox" -eq "$vm_name") {

					$test_vbox=1
					# Commande d'import de la VM Vbox
					Invoke-Command {& $vbox_path_ovftool import "$vm_path"
					if ( $? -eq 0 ) {
						affiche_error "Import de la VM virtualbox $vm_name a echoue !"
						delete_temp "$temp_path"
					}
					} | out-host
					
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

				$msgBoxInput = [System.Windows.Forms.Messagebox]::Show("La vm $vm_name existe déja sur le disque ! La supprimer ?",'VM Vmware','YesNo','Warning')

				switch ($msgBoxInput) {

					'Yes' {
					
						Remove-Item -Force -Recurse "$vmware_path_vm_folder\$vm_name"
						
						if ( $? -eq 0 ) {
							affiche_error "Suppression de la VM vmware $vm_name a echoue !"
							delete_temp "$temp_path"
						}
					}
					
					'No' {
					
						affiche_error "Import de la VM vmware $vm_name a echoue !"
						delete_temp "$temp_path"
					}
				}
			}

			# Commande d'import de la VM Vmware
			Invoke-Command {& "$vmware_path_ovftool\OVFTool\ovftool.exe" --lax --allowExtraConfig "$vm_path" "$vmware_path_vm_folder"
			if ( $? -eq 0 ) {
				affiche_error "Import de la VM vmware $vm_name a echoue !"
				delete_temp "$temp_path"
			}
			} | out-host
			
			Invoke-Command {& "$vmware_path_ovftool\vmware.exe" "$vmware_path_vm_folder\$vm_name\$vm_name.vmx"
			if ( $? -eq 0 ) {
				affiche_error "Import de la VM vmware $vm_name a echoue !"
				delete_temp "$temp_path"
			}
			}
		}

		Write-Host ""
		Write-Host "4. Import des vm dans $vmware_path_vm_folder terminee avec succes !" -ForegroundColor Green

		# Si le projet utilise Vmware il faut changer le chemin des Vms dans le fichier de configuration de GNS3
		if ( "$vm_vmware" -ne "" ) {

			$statusBar.Text = "Changement du chemin des VMs dans le fichier de configuration de GNS3 $($progress.Value) %"
			
			# Backup du fichier du fichier de configuration du projet GNS3

			Move-Item -Force -Path "$temp_path\$nom_project\$nom_project.gns3" -Destination "$temp_path\$nom_project\$nom_project.gns3.back.import"

			if ( $? -eq 0 ) {
					affiche_error "Copie du fichier gns3 du projet $temp_path\$nom_project\$nom_project.gns3 echoue !"
					delete_temp "$temp_path"
			}

			# Extrait le chemin des vm à changer dans fichier de configuration du projet

			$vm_path_temp=Get-ChildItem "$temp_path"
			$vm_path_gns3=Get-Content "$temp_path\$nom_project\$nom_project.gns3.back.import" | Where-Object {$_ -match "vmx"} | Foreach-Object {$_.split('"')[3]} | Select-Object -First 1
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
			# Creation du nouveau fichier de configuration de GNS3 avec le nouveau chemin des VMs
			
			Get-Content "$temp_path\$nom_project\$nom_project.gns3.back.import" | ForEach-Object {$_.replace("$old_vm_path","$vmware_path_vm_folder\\") } | Set-Content "$temp_path\$nom_project\$nom_project.gns3"
			
			if ( $? -eq 0 ) {
				affiche_error "Changement du repertoire de la VM $vm_path_projet echoue !"
				delete_temp "$temp_path"
			}

			Write-Host ""
			Write-Host "4. Changement du repertoire de la VM du projet $nom_project terminee avec succes !" -ForegroundColor Green
		}

	} else {
		Write-Host ""
		Write-Host "4. Aucune VM associé au projet !" -ForegroundColor Green
	}

	$progress.Value = 90	
	$statusBar.Text = “5. Import des fichiers du projet $($progress.Value) %”
	
	# Copie du project dans le répertoire local des projets de gns3

	New-Item -ItemType Directory -Force -Path "$gns3_proj_path_local\$nom_project" | Out-Null
	Copy-Item -Recurse -Force -Exclude images "$temp_path\$nom_project\*" "$gns3_proj_path_local\$nom_project"

	if ( $? -eq 0 ) {
		affiche_error "Copie du projet $nom_project echoue !"
		delete_temp "$temp_path"
	}

	Write-Host ""
	Write-Host "5. Copie du projet $nom_project reussi dans $gns3_proj_path_local\$nom_project !" -ForegroundColor Green

	# Création du répertoire du projet sur la vm gns3
	ssh_command "mkdir -p $gns3_projects_path_vm/$($project_file.project_id)/project-files"

	# Copie du project dans le répertoire de la vm gns3 des projets de gns3
	ssh_copie "$gns3_proj_path_local\$nom_project\project-files\" "$gns3_projects_path_vm/$($project_file.project_id)/project-files"

	Write-Host ""
	Write-Host "5. Copie du projet $nom_project reussi dans gns3_projects_path_vm/$($project_file.project_id) !" -ForegroundColor Green

	# Vidage des fichiers temporaire
	Remove-Item -Force -Recurse "$temp_path"

	Write-Host ""
	Write-Host "Import termine avec succes dans $gns3_proj_path_local\$nom_project !" -ForegroundColor Green
	
	$diff_time=NEW-TIMESPAN –Start $start_time_script –End $(Get-Date)
	$script_time="$($diff_time | Select-Object -ExpandProperty Hours)H $($diff_time | Select-Object -ExpandProperty Minutes)M $($diff_time | Select-Object -ExpandProperty Seconds)S"
	
	Write-Host ""
	Write-Host "############ Script terminé à $(Get-Date -format 'HH:mm:ss') pour $script_time ############"
    Write-Host ""
	
	$progress.Value = 100
	$statusBar.Text = “Script termine avec succes  $($progress.Value) %”
	
	[System.Windows.Forms.Messagebox]::Show('L importation est terminée : $script_time','Importation','OK','Info')
	
	$progress.Value = 0
	$statusBar.Text = "Prêt"
})

# Gestion event quand on clique sur le bouton choisir
$button_ProjetPath.Add_Click(
{
	$statusBar.Text = "Selectionner le dossier des projets"
	
    $openFolderDialog.Description      = "Selectionner le dossier des projets"
    $ret = $openFolderDialog.ShowDialog()

    if ($ret -ilike "ok") {
	
        $textbox_ProjetPath.Text = $openFolderDialog.SelectedPath
		
    }
	$statusBar.Text = "Prêt"
})

# Gestion event quand on clique sur le bouton choisir
$button_ImagesPath.Add_Click(
{
	$statusBar.Text = "Selectionner le dossier des images"
	
    $openFolderDialog.Description      = "Selectionner le dossier des images"        
    $ret = $openFolderDialog.ShowDialog()

    if ($ret -ilike "ok") {
        $textbox_ImagesPath.Text = $openFolderDialog.SelectedPath
        $script:gns3_images_path_local = $openFolderDialog.SelectedPath
    }
	$statusBar.Text = "Prêt"
})

# Gestion event quand on clique sur le bouton choisir
$button_TmpPath.Add_Click(
{
	$statusBar.Text = "Selectionner le dossier Temporaire"
	
    $openFolderDialog.Description      = "Selectionner le dossier Temporaire"        
    $ret = $openFolderDialog.ShowDialog()

    if ($ret -ilike "ok") {
        $textbox_TmpPath.Text = $openFolderDialog.SelectedPath
        $script:temp_path = $openFolderDialog.SelectedPath
    }
	$statusBar.Text = "Prêt"
})

# Gestion event quand on clique sur le bouton choisir
$button_ExportPath.Add_Click(
{
	$statusBar.Text = "Selectionner le dossier d'export"
	
    $openFolderDialog.Description      = "Selectionner le dossier d'export"        
    $ret = $openFolderDialog.ShowDialog()

    if ($ret -ilike "ok") {
        $textbox_ExportPath.Text = $openFolderDialog.SelectedPath
        $script:gns3_proj_path_src = $openFolderDialog.SelectedPath
		
		# Appel de la fonction qui affiche les projets
		affiche_projets
    }
	$statusBar.Text = "Prêt"
})

# Gestion event quand on clique sur le bouton choisir
$button_VMPath.Add_Click(
{
	$statusBar.Text = "Selectionner le dossier d'import des VMs Vmware"
	
    $openFolderDialog.Description      = "Selectionner le dossier d'import des VMs Vmware"        
    $ret = $openFolderDialog.ShowDialog()

    if ($ret -ilike "ok") {
        $textbox_VMPath.Text = $openFolderDialog.SelectedPath
        $script:vmware_path_vm_folder = $openFolderDialog.SelectedPath
    }
	$statusBar.Text = "Prêt"
})

#################################################
# INSERTION DES COMPOSANTS
#################################################

# Ajout des composants a la Form
$form.Controls.Add($label_title)
$form.Controls.Add($label_progressbar)
$form.Controls.Add($progress)
$form.Controls.Add($button_Export)
# $form.Controls.Add($button_Cancel)
$form.Controls.Add($button_quit)
$form.Controls.Add($groupBox_include_images)
$form.Controls.Add($groupBox_archive_projet)
$form.Controls.Add($choix_options)
$form.Controls.Add($choix_projets)
$form.Controls.Add($choix_compress_vms)
$form.Controls.Add($statusBar)

# Affichage de la Windows
$form.ShowDialog()