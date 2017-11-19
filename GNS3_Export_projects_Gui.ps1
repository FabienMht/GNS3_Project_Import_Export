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

    1.0     2017.09.12   Fabien MAUHOURAT   Initial Version
    1.1     2017.09.28   Fabien MAUHOURAT   Ajout de la compatibilité Vbox et de la fonction de calcul de l'espace disque
	2.0		2017.11.19   Fabien MAUHOURAT   Ajout de la GUI et correction de BUGs changement d'adaptateur et export import de VM Vbox '
											et amélioration export de container docker et telechargement automatique de putty 
											Possibilité de ne pas inclure les images avec le projet de ne pas compresser l'export et de modifier le parametre de compression de vmware

#>

# Définition des variables
# Le dossier d'installation de Putty doit etre dans la variable PATH

[cmdletbinding()]
param (

    [parameter(Mandatory=$false)]
    [string]$IncludeImages=$true,

	[parameter(Mandatory=$false)]
    [string]$ArchiveProjet=$true,
	
    # Variables à changer
    [Parameter(Mandatory=$false, Position=1)]
    [Alias("ProjectPath")]
    [string]$gns3_proj_path_local="C:\Users\$env:UserName\GNS3\projects",

    [Parameter(Mandatory=$false, Position=2)]
    [Alias("ImagesPath")]
    [string]$gns3_images_path_local="C:\Users\$env:UserName\GNS3\images",

    [Parameter(Mandatory=$false, Position=3)]
    [Alias("IPGns3vm")]
    [string]$ip_vm_gns3="",

    [Parameter(Mandatory=$false, Position=4)]
    [Alias("TmpPath")]
    [string]$temp_path="C:\Temp",

    [Parameter(Mandatory=$false, Position=5)]
    [Alias("ExportPath")]
    [string]$export_project_path="C:\Temp",

    # Variables par défaut
    [string]$gns3_proj_path_vm="/opt/gns3/projects",
    [string]$pass_gns3_vm="gns3",
    [string]$user_gns3_vm="gns3",
    [string]$vmware_path_ovftool="C:\Program Files (x86)\VMware\VMware Workstation",
    [string]$vbox_path_ovftool="C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
	[string]$putty_path=""
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
	
    # Si les images doivent être incluse au projet
    if ($IncludeImages -eq $true) {
        if ( $gns3_images_path_local -eq "" -or ! (Test-Path $gns3_images_path_local) ) {
            affiche_error "La variable gns3_images_path_local n est pas definie !"
            exit
        }
        if ( $gns3_proj_path_vm -eq "" ) {
            affiche_error "La variable gns3_proj_path_vm n est pas definie !"
            exit
        }
    }
	
	# Vérifie si les variables sont nulles
    if ( $temp_path -eq "" ) {
        affiche_error "La variable temp_path n est pas definie !"
        exit
    }
    if ( $export_project_path -eq "" ) {
        affiche_error "La variable export_project_path n est pas definie !"
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

	if ( ($nom_project -eq "") -or ! (Test-Path "$gns3_proj_path_local\$($nom_project)\$($nom_project).gns3") ) {
		affiche_error "Le projet selectionner n existe pas !"
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
	
    # Crée le repertoire d'export
	New-Item -ItemType Directory -Force -Path "$export_project_path" | Out-Null
    if ( $? -eq 0 ) {
        affiche_error "Creation du dossier $export_project_path echoue !"
        exit
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
    Write-Host "1. Verification des parametres terminee sans erreur :" -ForegroundColor Green
    Write-Host ""
    Write-Host "La configuration est la suivante :"
    Write-Host "     * Chemin projects : $gns3_proj_path_local"
    if ($IncludeImages -eq $true) {
        Write-Host "     * Chemin images : $gns3_images_path_local"
    }
    Write-Host "     * Chemin temporaire du project : $temp_path"
    Write-Host "     * Chemin d export du project : $export_project_path"
    Write-Host "     * IpVM GNS3 : $ip_vm_gns3"
	Write-Host "     * Projet : $nom_project"
    Write-Host ""
}

# Fonction qui verifie les paramètres du script
function verify-param-vm {

        # Si le projet utilise Vmware : verifie la variable du chemin de l'utilitaire ovftool
        if ( ($vm_project | Where-Object {$_.node_type -match "vmware"}) -ne $null ) {
            if ( $vmware_path_ovftool -eq "" -or ! (Test-Path $vmware_path_ovftool) ) {
                affiche_error "La variable vmware_path_ovftool n est pas definie ou le chemin n existe pas !"
                delete_temp
            }
        }

        # Si le projet utilise Vbox : verifie la variable du chemin de l'utilitaire vboxmanage
        if ( ($vm_project | Where-Object {$_.node_type -match "virtualbox"}) -ne $null ) {
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

            $vm_path=Invoke-Command {& $vbox_path_ovftool showvminfo "$($vm.properties.vmname)"} | Where-Object {$_ -match "Config file"}
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
        $folder_size=$folder_size + ((Get-ChildItem "$folder_vm_name" -recurse | Where-Object { -not $_.PSIsContainer } | Measure-Object -property length -sum).Sum / 1GB)
    }

	Write-Host ""
    Write-Host "Taille du projet : $("{0:N1}" -f ($folder_size)) GB !"
    Write-Host "Taille du projet apres export : $("{0:N1}" -f ($folder_size * 80 / 100)) GB !"
	Write-Host "Temps estime d export du projet : $("{0:N2}" -f ($folder_size * 18 / 9.2 / 60)) H !"
	
    # Récuperation des lettres des lecteurs
    $root_temp="$(($temp_path).Split(':')[0])"
    $root_export="$(($export_project_path).Split(':')[0])"

    # Vérifie si les lettres de lecteur sont les mêmes
    if ("$root_temp" -eq "$root_export") {
        $root_test=1
        $folder_size=$folder_size * 2
    }

    # Verifie pour chaque disque que la taille est suffisante en fonction du projet
    foreach ($disk in "$root_temp","$root_export") {

        
        $size_disk=(Get-PSDrive "$(($disk).Split(':')[0])" | Select-Object -ExpandProperty Free) / 1GB
        $size_after_export=$([int]$size_disk) - $([int]$folder_size)

        # Si la taille du projet dépasse la taille du disque alors le script s'arrete
        if ([int]$folder_size -gt [int]$size_disk) {

            Write-Host ""
            affiche_error "La taille du disque $disk est insuffisante $size_after_export GB pour exporter le projet : $("{0:N1}" -f ($folder_size)) GB !"

            # Vérifie l'espace libre des autres disques
            $other_disk=Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Name -notmatch "$disk"} | Select-Object name,free

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
    Write-Host "Export de l image $images_name en cours ..."

	$statusBar.Text = "Export de l image $images_name en cours  $($progress.Value) %"
	
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

    $images_test=Get-ChildItem -Path "$temp_path\$nom_project\images\$type" | Where-Object {$_ -match "^$($images_name)$"}
    return "$images_test"
}

# Fonction qui cherche les images du project
function find_images {

    Param(
      [string]$images_name
    )

	# Recherche l'image en cours dans le dossier ou elles sont stockées
    $images_path_temp=Get-ChildItem -Path "$gns3_images_path_local" -Recurse | Where-Object {$_ -match "^$($images_name)$"}

    if ( "$images_path_temp" -eq ""  ) {
        affiche_error "Images $images_name introuvable dans le repertoire $gns3_images_path_local !"
        delete_temp
    }

	# Selection du chemin de l'image
    $images_path=$images_path_temp.PSPath | ForEach-Object {$_.split('::')[2] + ":" + $_.split('::')[3]}

    return $images_path
}

# Fonction qui execute une commande ssh sur la VM GNS3
function ssh_command {

    Param(
      [string]$command
    )

	# Commande SSH avec Putty
    & "$($putty_path)plink.exe" -pw "$pass_gns3_vm" "$user_gns3_vm@$ip_vm_gns3" "$command"

    if ( $? -eq 0 ) {
        affiche_error "Commande $command a echoue sur l hote $ip_vm_gns3 avec l utilisateur $user_gns3_vm !" | Out-Null
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
    & "$($putty_path)pscp.exe" -pw "$pass_gns3_vm" -r "$user_gns3_vm@$($ip_vm_gns3):$source" "$dest" | Out-Null

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
	
	$statusBar.Text = "$args"
	$progress.Value = 0
	
	[System.Windows.Forms.Messagebox]::Show("$args",'Script d import','OK','Error')

}

# Fonction qui supprime les fichiers temporaires du script
function delete_temp {

    Remove-Item -Force -Recurse $temp_path
    exit

}

# Fonction qui affiche les erreurs du script
function affiche_projets {

	Write-Host ""
	Write-Host "Liste des projects GNS3 :" -ForegroundColor Green
	Write-Host ""

	$script:gns3_proj_path_local = $textbox_ProjetPath.Text

	# Affichage de tous les dossiers contenant un fichier de configuration GNS3
	$cmb_Choix_Projets.Items.clear()
	$compteur=0
	
	Get-ChildItem $gns3_proj_path_local | Select-Object Name | ForEach-Object { 
		if (Test-Path "$gns3_proj_path_local\$($_.name)\$($_.name).gns3") {
			$compteur=$compteur+1
			Write-Host "$compteur." $_.name
			$cmb_Choix_Projets.Items.Add($_.name) | Out-Null
		}
	}
}

function About {

    $statusBar.Text = "About"
	
    # About Form Objects
    $aboutForm          = New-Object System.Windows.Forms.Form
    $aboutFormExit      = New-Object System.Windows.Forms.Button
    $aboutFormImage     = New-Object System.Windows.Forms.PictureBox
    $aboutFormNameLabel = New-Object System.Windows.Forms.Label
    $aboutFormText      = New-Object System.Windows.Forms.Label

    # About Form
    $aboutForm.AcceptButton  = $aboutFormExit
    $aboutForm.CancelButton  = $aboutFormExit
    $aboutForm.ClientSize    = "350, 125"
    $aboutForm.ControlBox    = $false
    $aboutForm.ShowInTaskBar = $false
    $aboutForm.StartPosition = "CenterParent"
    $aboutForm.Text          = "About GNS3_Project_Import_Export"
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

    # About Text Label
    $aboutFormText.Location = "145, 55"
    $aboutFormText.Size     = "300, 30"
    $aboutFormText.Text     = "Fabien Mauhourat `n`r      Version 2.0"
    $aboutForm.Controls.Add($aboutFormText)

    # About Exit Button
    $aboutFormExit.Location = "155, 85"
    $aboutFormExit.Text     = "OK"
    $aboutForm.Controls.Add($aboutFormExit)

    $aboutForm.ShowDialog()
	
    $statusBar.Text = "Ready"
}

Write-Host "###########################################################################"
Write-Host "################## Script d exportation des projets GNS3 ##################"
Write-Host "###########################################################################"

#################################################
# Creation des objets de la fenetre
#################################################

# Chargement des Windows Form
Add-Type –AssemblyName System.Windows.Forms
[Windows.Forms.Application]::EnableVisualStyles()     
$host.ui.RawUI.WindowTitle = "Export de projet GNS3 v2.0 Fabien Mauhourat"

# Définission des objets de la fenetre
$form = New-Object System.Windows.Forms.Form

# Extract PowerShell Icon from PowerShell Exe
$iconPS   = [Drawing.Icon]::ExtractAssociatedIcon((Get-Command powershell).Path)

# Définision des buttons
$button_Export = New-Object System.Windows.Forms.Button
$button_Cancel = New-Object System.Windows.Forms.Button
$button_quit = New-Object System.Windows.Forms.Button
$button_ProjetPath = New-Object System.Windows.Forms.Button
$button_ImagesPath = New-Object System.Windows.Forms.Button
$button_TmpPath = New-Object System.Windows.Forms.Button
$button_ExportPath = New-Object System.Windows.Forms.Button
$button_IPPing = New-Object System.Windows.Forms.Button

# Définission des textboxs
$textbox_ProjetPath = New-Object System.Windows.Forms.TextBox
$textbox_ImagesPath = New-Object System.Windows.Forms.TextBox
$textbox_TmpPath = New-Object System.Windows.Forms.TextBox
$textbox_ExportPath = New-Object System.Windows.Forms.TextBox
$textbox_IPGns3vm = New-Object System.Windows.Forms.TextBox

# Définission des Labels
$label_title = New-Object System.Windows.Forms.Label
$label_ProjetPath = New-Object System.Windows.Forms.Label
$label_ImagesPath = New-Object System.Windows.Forms.Label
$label_TmpPath = New-Object System.Windows.Forms.Label
$label_ExportPath = New-Object System.Windows.Forms.Label
$label_IPGns3vm = New-Object System.Windows.Forms.Label
$label_progressbar = New-Object System.Windows.Forms.Label

# Définission des groupbox
$groupBox_include_images = New-Object System.Windows.Forms.GroupBox
$groupBox_archive_projet = New-Object System.Windows.Forms.GroupBox
$choix_options = New-Object System.Windows.Forms.GroupBox
$choix_projets= New-Object System.Windows.Forms.GroupBox
$choix_compress_vms= New-Object System.Windows.Forms.GroupBox

# Définission des Barres d'information d'avancement du script
$statusBar = New-Object System.Windows.Forms.StatusBar
$progress = New-Object System.Windows.Forms.ProgressBar

# Définission des ComboBox
$cmb_Choix_Projets = New-Object System.Windows.Forms.ComboBox
$cmb_compress_vms = New-Object System.Windows.Forms.ComboBox
$openFolderDialog = New-Object System.Windows.Forms.FolderBrowserDialog

# Définission des Buttons radio
$include_images_no = New-Object System.Windows.Forms.RadioButton
$include_images_yes = New-Object System.Windows.Forms.RadioButton
$archive_projet_no = New-Object System.Windows.Forms.RadioButton
$archive_projet_yes = New-Object System.Windows.Forms.RadioButton

# Menu
$menuMain         = New-Object System.Windows.Forms.MenuStrip
$menuFile         = New-Object System.Windows.Forms.ToolStripMenuItem
$menuExit         = New-Object System.Windows.Forms.ToolStripMenuItem
$menuHelp         = New-Object System.Windows.Forms.ToolStripMenuItem
$menuAbout        = New-Object System.Windows.Forms.ToolStripMenuItem
$menuDoc		  = New-Object System.Windows.Forms.ToolStripMenuItem

#################################################
# CONFIGURATION DE LA WINDOWS FORM
#################################################

# Creation de la form principale
$form.FormBorderStyle = 1
$form.MaximizeBox = $False
$form.MinimizeBox = $False
$form.Icon = $iconPS
$form.Text = "Export de projet GNS3 v2.0 Fabien Mauhourat"
$form.StartPosition= 1
$form.Size = New-Object System.Drawing.Size(540,750)
$form.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,13,0,2,1)

#################################################
# AJOUT DES COMPOSANTS
#################################################

# Bouton monter
$button_Export.Text = "Exporter Projet"
$button_Export.Size = New-Object System.Drawing.Size(390,40)
$button_Export.Location = New-Object System.Drawing.Size(65,580)

# Bouton dem
$button_Cancel.Text = "Demonter l'image !"
$button_Cancel.Size = New-Object System.Drawing.Size(185,40)
$button_Cancel.Location = New-Object System.Drawing.Size(270,580)

# Bouton Quitter
$button_quit.Text = "Fermer"
$button_quit.Size = New-Object System.Drawing.Size(390,40)
$button_quit.Location = New-Object System.Drawing.Size(65,630)

# Bouton ProjetPath
$button_ProjetPath.Text = "..."
$button_ProjetPath.Size = New-Object System.Drawing.Size(25,27)
$button_ProjetPath.Location = New-Object System.Drawing.Size(440,47)

# Bouton ImagesPath
$button_ImagesPath.Text = "..."
$button_ImagesPath.Size = New-Object System.Drawing.Size(25,27)
$button_ImagesPath.Location = New-Object System.Drawing.Size(440,97)

# Bouton TmpPath
$button_TmpPath.Text = "..."
$button_TmpPath.Size = New-Object System.Drawing.Size(25,27)
$button_TmpPath.Location = New-Object System.Drawing.Size(440,147)

# Bouton ExportPath
$button_ExportPath.Text = "..."
$button_ExportPath.Size = New-Object System.Drawing.Size(25,27)
$button_ExportPath.Location = New-Object System.Drawing.Size(440,197)

# Bouton Ping
$button_IPPing.Text = "Ping"
$button_IPPing.Size = New-Object System.Drawing.Size(40,27)
$button_IPPing.Location = New-Object System.Drawing.Size(432,247)

# Label title
$label_title.Location = New-Object System.Drawing.Point(170,33)
$label_title.Size = New-Object System.Drawing.Size(380,30)
$label_title.Text = "Export Projets Gns3"
$label_title.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,16,1,2,1)
$label_title.TabIndex = 1

# TextBox ProjetPath
$textbox_ProjetPath.AutoSize = $true
$textbox_ProjetPath.Location = New-Object System.Drawing.Point(20,50)
$textbox_ProjetPath.Size = New-Object System.Drawing.Size(405,25)
$textbox_ProjetPath.Text = $gns3_proj_path_local

# TextBox ImagesPath
$textbox_ImagesPath.AutoSize = $true
$textbox_ImagesPath.Location = New-Object System.Drawing.Point(20,100)
$textbox_ImagesPath.Size = New-Object System.Drawing.Size(405,10)
$textbox_ImagesPath.Text = $gns3_images_path_local

# TextBox TmpPath
$textbox_TmpPath.AutoSize = $true
$textbox_TmpPath.Location = New-Object System.Drawing.Point(20,150)
$textbox_TmpPath.Size = New-Object System.Drawing.Size(405,50)
$textbox_TmpPath.Text = $temp_path

# TextBox ExportPath
$textbox_ExportPath.AutoSize = $true
$textbox_ExportPath.Location = New-Object System.Drawing.Point(20,200)
$textbox_ExportPath.Size = New-Object System.Drawing.Size(405,50)
$textbox_ExportPath.Text = $export_project_path

# TextBox IPGns3vm
$textbox_IPGns3vm.AutoSize = $true
$textbox_IPGns3vm.Location = New-Object System.Drawing.Point(20,250)
$textbox_IPGns3vm.Size = New-Object System.Drawing.Size(405,50)
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
$label_ExportPath.Text = "Dossier d'export :"

# Label IPGns3vm
$label_IPGns3vm.AutoSize = $true
$label_IPGns3vm.Location = New-Object System.Drawing.Point(20,230)
$label_IPGns3vm.Text = "Ip VM GNS3 :"

# Label progressbar
$label_progressbar.AutoSize = $true
$label_progressbar.Location = New-Object System.Drawing.Point(65,515)
$label_progressbar.Text = "6. L'avancement :"

# Barre de status
$statusBar.DataBindings.DefaultDataSourceUpdateMode = 0
$statusBar.Location = New-Object System.Drawing.Point(0,680)
$statusBar.Name = “statusBar”
$statusBar.Size = New-Object System.Drawing.Size(440,23)
$statusBar.Text = "Ready"
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
$cmb_Choix_Projets.Size            = New-Object System.Drawing.Size(200,20)
$cmb_Choix_Projets.TabIndex        = 0

# ComboBox qui affiche le niveau de compression des VMs
$cmb_compress_vms.DataBindings.DefaultDataSourceUpdateMode = 0
$cmb_compress_vms.AutoSize = 1
$cmb_compress_vms.FormattingEnabled = $True
$cmb_compress_vms.Location        = New-Object System.Drawing.Point(20,22)
$cmb_compress_vms.Name            = "cmb_compress_vms"
$cmb_compress_vms.Size            = New-Object System.Drawing.Size(160,20)
$cmb_compress_vms.TabIndex        = 0

foreach ($compress in "1","5","9") {
	$cmb_compress_vms.Items.Add($compress) | Out-Null
}

$cmb_compress_vms.SelectedIndex = 2


############## Groupe de radio bouton Include Image ###################

$groupBox_include_images.DataBindings.DefaultDataSourceUpdateMode = 0
$groupBox_include_images.Location = New-Object System.Drawing.Point(20,447)
$groupBox_include_images.Size = New-Object System.Drawing.Size(230,50)
$groupBox_include_images.TabIndex = 3
$groupBox_include_images.TabStop = $False
$groupBox_include_images.Text = “4. Inclure les Images et containers”
$groupBox_include_images.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,13,0,2,1)

$include_images_no.DataBindings.DefaultDataSourceUpdateMode = 0
$include_images_no.Location = New-Object System.Drawing.Point(130,20)
$include_images_no.Size = New-Object System.Drawing.Size(60,20)
$include_images_no.Name = “radioButton2”
$include_images_no.TabIndex = 1
$include_images_no.TabStop = $True
$include_images_no.Text = “Non”
$include_images_no.UseVisualStyleBackColor = $True

$include_images_yes.DataBindings.DefaultDataSourceUpdateMode = 0
$include_images_yes.Location = New-Object System.Drawing.Point(50,20)
$include_images_yes.Size = New-Object System.Drawing.Size(70,20)
$include_images_yes.Name = “radioButton1”
$include_images_yes.TabIndex = 0
$include_images_yes.TabStop = $True
$include_images_yes.Text = “Oui”
$include_images_yes.UseVisualStyleBackColor = $True
$include_images_yes.checked =$True

$groupBox_include_images.Controls.Add($include_images_no)
$groupBox_include_images.Controls.Add($include_images_yes)

############# Groupe de radio bouton Archive projet ################

$groupBox_archive_projet.DataBindings.DefaultDataSourceUpdateMode = 0
$groupBox_archive_projet.Location = New-Object System.Drawing.Point(270,447)
$groupBox_archive_projet.Size = New-Object System.Drawing.Size(230,50)
$groupBox_archive_projet.TabIndex = 3
$groupBox_archive_projet.TabStop = $False
$groupBox_archive_projet.Text = “5. Archiver le projet”
$groupBox_archive_projet.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,13,0,2,1)

$archive_projet_no.DataBindings.DefaultDataSourceUpdateMode = 0
$archive_projet_no.Location = New-Object System.Drawing.Point(130,20)
$archive_projet_no.Size = New-Object System.Drawing.Size(80,20)
$archive_projet_no.Name = “radioButton2”
$archive_projet_no.TabIndex = 1
$archive_projet_no.TabStop = $True
$archive_projet_no.Text = “Non”
$archive_projet_no.UseVisualStyleBackColor = $True

$archive_projet_yes.DataBindings.DefaultDataSourceUpdateMode = 0
$archive_projet_yes.Location = New-Object System.Drawing.Point(50,15)
$archive_projet_yes.Size = New-Object System.Drawing.Size(90,30)
$archive_projet_yes.Name = “radioButton1”
$archive_projet_yes.TabIndex = 0
$archive_projet_yes.TabStop = $True
$archive_projet_yes.Text = “Oui”
$archive_projet_yes.UseVisualStyleBackColor = $True
$archive_projet_yes.checked =$True

$groupBox_archive_projet.Controls.Add($archive_projet_no)
$groupBox_archive_projet.Controls.Add($archive_projet_yes)

############# Groupe de radio bouton Choix de la configuration ################

$choix_options.DataBindings.DefaultDataSourceUpdateMode = 0
$choix_options.Location = New-Object System.Drawing.Point(20,67)
$choix_options.Size = New-Object System.Drawing.Size(480,290)
$choix_options.TabIndex = 3
$choix_options.TabStop = $False
$choix_options.Text = “1. Choisir les options de configuration”
$choix_options.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,13,0,2,1)

$choix_options.Controls.Add($textbox_ProjetPath)
$choix_options.Controls.Add($textbox_ImagesPath)
$choix_options.Controls.Add($textbox_TmpPath)
$choix_options.Controls.Add($textbox_ExportPath)
$choix_options.Controls.Add($textbox_IPGns3vm)
$choix_options.Controls.Add($button_ProjetPath)
$choix_options.Controls.Add($button_ImagesPath)
$choix_options.Controls.Add($button_TmpPath)
$choix_options.Controls.Add($button_ExportPath)
$choix_options.Controls.Add($button_IPPing)
$choix_options.Controls.Add($label_ProjetPath)
$choix_options.Controls.Add($label_ImagesPath)
$choix_options.Controls.Add($label_IPGns3vm)
$choix_options.Controls.Add($label_TmpPath)
$choix_options.Controls.Add($label_ExportPath)

############# Groupe de radio bouton Choix du projet ################

$choix_projets.DataBindings.DefaultDataSourceUpdateMode = 0
$choix_projets.Location = New-Object System.Drawing.Point(20,372)
$choix_projets.Size = New-Object System.Drawing.Size(245,60)
$choix_projets.TabIndex = 3
$choix_projets.TabStop = $False
$choix_projets.Text = “2. Choisir Projet :”
$choix_projets.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,13,0,2,1)

$choix_projets.Controls.Add($cmb_Choix_Projets)

# Appel de la fonction qui affiche les projets
affiche_projets

############# Groupe de radio bouton Compression des Vms ################

$choix_compress_vms.DataBindings.DefaultDataSourceUpdateMode = 0
$choix_compress_vms.Location = New-Object System.Drawing.Point(300,372)
$choix_compress_vms.Size = New-Object System.Drawing.Size(200,60)
$choix_compress_vms.TabIndex = 3
$choix_compress_vms.TabStop = $False
$choix_compress_vms.Text = “3. Compression des Vms :”
$choix_compress_vms.Font = New-Object System.Drawing.Font(“Microsoft Sans Serif”,13,0,2,1)

$choix_compress_vms.Controls.Add($cmb_compress_vms)

#################### Main Menu ######################

# Main Menu Bar
$form.Controls.Add($menuMain)

# Menu Options - File
$menuFile.Text = "&File"
[void]$menuMain.Items.Add($menuFile)

# Menu Options - File / Exit
$menuExit.ShortcutKeys = "Control, Q"
$menuExit.Text         = "&Exit"
$menuExit.Add_Click({$form.Close()})
[void]$menuFile.DropDownItems.Add($menuExit)

# Menu Options - Help
$menuHelp.Text      = "&Help"
[void]$menuMain.Items.Add($menuHelp)

# Menu Options - Help / About
# $menuDoc.Image     = [System.Drawing.SystemIcons]::Information
$menuDoc.Text      = "Documentation"
$menuDoc.Add_Click({Start-Process https://github.com/FabienMht/GNS3_Project_Import_Export})
[void]$menuHelp.DropDownItems.Add($menuDoc)

# Menu Options - Help / About
$menuAbout.Image     = [System.Drawing.SystemIcons]::Information
$menuAbout.Text      = "About MenuStrip"
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
	
	$statusBar.Text = "Ready"
})

# Gestion event quand on clique sur le bouton OK
$button_Export.Add_Click(
{
    $progress.Value = 0
	$start_time_script = Get-Date
	
	#Déclaration des variables
	if ( ! $cmb_Choix_Projets.SelectedItem ) {
		affiche_error "Aucun projet selectionné !"
		exit
	}
	$nom_project=$($cmb_Choix_Projets.SelectedItem.ToString())
	
	if ( ! $cmb_compress_vms.SelectedItem ) {
		affiche_error "La compression du projet n a pas ete selectionne !"
		exit
	}
	$compress_vm=$($cmb_compress_vms.SelectedItem.ToString())

	$gns3_proj_path_local=$textbox_ProjetPath.Text
	$gns3_images_path_local=$textbox_ImagesPath.Text
	$ip_vm_gns3=$textbox_IPGns3vm.Text
	$temp_path="$($textbox_TmpPath.Text)\GNS3-TEMP"
	$export_project_path=$textbox_ExportPath.Text

	# Récupere la valeur des checkbox
	if ($include_images_yes.checked -ne $True) {
		$IncludeImages=$false
	}
	if ($archive_projet_yes.checked -ne $True) {
		$ArchiveProjet=$false
	}
	
	# Vérification des paramètres
	$statusBar.Text = “1. Vérification des paramètres $($progress.Value) %”
	verify-param

	Write-Host "Projet $nom_project selectionne !" -ForegroundColor Green

	$progress.Value = 5
	$statusBar.Text = “Copie du project dans le répertoire temporaire $($progress.Value) %”
	
	# Copie du project dans le répertoire temporaire

	Copy-Item -Recurse -Force -Path "$gns3_proj_path_local\$nom_project" -Destination "$temp_path"

	if ( $? -eq 0 ) {
		affiche_error "Copie du projet $nom_project echoue !"
		delete_temp
	}

	Write-Host ""
	Write-Host "2. Copie du projet $nom_project reussi dans $temp_path\$nom_project !" -ForegroundColor Green

	$progress.Value = 10
	$statusBar.Text = “Vérification de l espace disque et des paramètres des Vms $($progress.Value) %”
	
	# Recuperation du contenu au format JSON du fichier de configuration du projet GNS3
	$project_file=Get-Content "$temp_path\$nom_project\$nom_project.gns3" | ConvertFrom-Json

	# Selection des noeuds qui correspondent à des VM VMWARE et VBOX
	$vm_project=$($project_file.topology.nodes) | Where-Object {$_.node_type -match "vmware" -or $_.node_type -match "virtualbox"}

	# Selection des noeuds
	$image_project=$($project_file.topology.nodes) | Where-Object {$_.node_type -match "qemu" -or $_.node_type -match "iou" -or $_.node_type -match "dynamips" -or $_.node_type -match "docker"}

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

	$progress.Value = 15
	$statusBar.Text = “3. Récuperation des données du project de la vm gns3  $($progress.Value) %”
	
	# Vérification de l'existance du projet sur la VM
	ssh_command "cd $gns3_proj_path_vm/$($project_file.project_id)" 

	# Récuperation des données du project de la vm gns3
	ssh_copie "$gns3_proj_path_vm/$($project_file.project_id)/project-files" "$temp_path\$nom_project"

	
	Write-Host ""
	Write-Host "3. Copie des fichiers du project $nom_project reussi dans $temp_path\$nom_project\project-files !" -ForegroundColor Green

	
	# Si les Images doivent être incluse au projet
	if ( ($IncludeImages -eq $true) -and ($image_project -ne $null) ) {

		$progress.Value = 20
		$statusBar.Text = “4. Export des images du project $($progress.Value) %”
		
		Write-Host ""
		Write-Host "4. Export des images du project dans $temp_path\$nom_project\images en cours ..." -ForegroundColor Green
	
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

					$image_file_name="$($images.properties | Select-Object -ExpandProperty hd$($lettre)_disk_image)"
				
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
				if ( ($($images.properties.image) -match "/") -or ($($images.properties.image) -match ":") ) {
				
					$container_name=$($images.properties.image).replace('/','_')
					$container_name=$container_name.replace(':','_')
					
				} else {
					$container_name=$($images.properties.image)
				}
					
				# Vérifie si l'image à déjà été copié
				if ( $(verify_images "$container_name" "docker") ) {continue}
			
				Write-Host ""
				Write-Host "Export du container $container_name en cours ..."

				# Export l'image docker dans le dossier temporaire
				ssh_command "docker save $($images.properties.image) > /tmp/$container_name.tar"
				
				ssh_copie "/tmp/$container_name.tar" "$temp_path\$nom_project\images\docker\$container_name.tar"
	
				ssh_command "rm /tmp/$container_name.tar"
				
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
		Write-Host "4. Export des images dans $temp_path\$nom_project\images terminee avec succes !" -ForegroundColor Green

	} else {
	
		Write-Host ""
		Write-Host "4. Aucune images a exporter ou l option d inclure les images est desactive !" -ForegroundColor Green
	}
		
	# Export des vms du project en ovf
	# Si le projet inclut des VMs

	if ($vm_project -ne $null) {

		$progress.Value = 30	
		$statusBar.Text = “5. Export des vms du project en ovf $($progress.Value) %”
		
		Write-Host ""
		Write-Host "5. Export des VMs dans $temp_path en cours ..." -ForegroundColor Green
	
		$vm_count=$($vm_project | Measure-Object -Property name | Select-Object -ExpandProperty Count)
		$progress_count= 50 / $vm_count
		$progress_vm=40
		$compteur_vms=0
		
		foreach ($vm in $($vm_project)) {
			
			$compteur_vms+=1
			
			Write-Host ""
			Write-Host "$compteur_vms/$vm_count Export de la VM $($vm.name) en cours :" -ForegroundColor Green
			Write-Host ""
			
			$statusBar.Text = "$compteur_vms/$vm_count Export de la VM $($vm.name) en cours $($progress.Value) %"
			$progress_vm= $progress_vm + $progress_count
			
			# Export des vm vmware dans le repertoire temporaire
			if ($($vm.node_type) -match "vmware") {
		
				# Export des VMs dans le dossier temporaire du script
				Invoke-Command {& "$vmware_path_ovftool\OVFTool\ovftool.exe" --compress="$($compress_vm)" "$($vm.properties.vmx_path)" "$temp_path"
				if ( $? -eq 0 ) {
					affiche_error "Export de la VM $($vm.name) echoue !"
					delete_temp
				}
				} | out-host
				
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
			
			$progress.Value = $progress_vm
		}

		if ("$($vm.properties.use_any_adapter)" -match "false") {

			# Backup du fichier du fichier de configuration du projet GNS3

			Move-Item -Force -Path "$temp_path\$nom_project\$nom_project.gns3" -Destination "$temp_path\$nom_project\$nom_project.gns3.back.export"

			if ( $? -eq 0 ) {
				affiche_error "Copie du fichier gns3 du projet $temp_path\$nom_project\$nom_project.gns3 echoue !"
				delete_temp
			}

			# Changement du repertoire des vm dans le fichier GNS3 du projet
			# Creation du nouveau fichier de configuration de GNS3 avec le nouveau chemin des VMs

			Get-Content "$temp_path\$nom_project\$nom_project.gns3.back.export" | ForEach-Object {$_.replace('"use_any_adapter": false','"use_any_adapter": true')} | Set-Content "$temp_path\$nom_project\$nom_project.gns3"

			if ( $? -eq 0 ) {
				affiche_error "Changement du parametre use_any_adapter dans le fichier de configuration de GNS3 echoue !"
				delete_temp
			}

			Write-Host ""
			Write-Host "Changement du parametre use_any_adapter dans le fichier de configuration de GNS3 terminee avec succes !" -ForegroundColor Green

		}

		Write-Host ""
		Write-Host "5. Export des VMs dans $temp_path terminee avec succes !" -ForegroundColor Green

	} else {
	
		Write-Host ""
		Write-Host "5. Aucune VM a exporter !" -ForegroundColor Green
	}

	Remove-Item -Force -Recurse "$temp_path\putty" *> $null
	
	if ($ArchiveProjet -eq $true) {

		$progress.Value = 80	
		$statusBar.Text = “6. Compression du project $($progress.Value) %”
		
		# Compression du project

		Write-Host ""
		Write-Host "6. Compression de $nom_project en cours ..." -ForegroundColor Green

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
		Write-Host "6. Compression de $nom_project reussi dans $export_project_path\$nom_project !" -ForegroundColor Green
		
		# Vidage des fichiers temporaire
		Remove-Item -Force -Recurse $temp_path
	
	} else {
	
		$progress.Value = 80
		$statusBar.Text = “6. Copie du project dans le répertoire d export $($progress.Value) %”
		
		Write-Host ""
		Write-Host "6. Déplacement du projet vers le dossier d export : $export_project_path\$nom_project ..." -ForegroundColor Green
		
		if (Test-Path "$export_project_path\$nom_project") {
			# Vidage des fichiers temporaire
			Remove-Item -Force -Recurse "$export_project_path\$nom_project"
		}

		Move-Item -Force -Path "$temp_path\" -Destination "$export_project_path\$nom_project"
		
		Write-Host ""
		Write-Host "6. Le projet $nom_project est deplacé dans $export_project_path\$nom_project !" -ForegroundColor Green
	}

	Write-Host ""
	Write-Host "Export termine avec succes dans $export_project_path\$nom_project !" -ForegroundColor Green
	
	$diff_time=NEW-TIMESPAN –Start $start_time_script –End $(Get-Date)
	$script_time="$($diff_time | Select-Object -ExpandProperty Hours)H $($diff_time | Select-Object -ExpandProperty Minutes)M $($diff_time | Select-Object -ExpandProperty Seconds)S"
	
	Write-Host ""
	Write-Host "############ Script terminé à $(Get-Date -format 'HH:mm:ss') pour $script_time ############"
    Write-Host ""
	
	$progress.Value = 100
	$statusBar.Text = “Script termine avec succes  $($progress.Value) %”
	
	[System.Windows.Forms.Messagebox]::Show("L exportation est terminée : $script_time",'Exportation','OK','Info')
	
	$progress.Value = 0
	$statusBar.Text = "Ready"
})

# Gestion event quand on clique sur le bouton choisir
$button_ProjetPath.Add_Click(
{
    $openFolderDialog.Description      = "Selectionner le dossier des projets"
    $ret = $openFolderDialog.ShowDialog()

    if ($ret -ilike "ok") {
	
        $textbox_ProjetPath.Text = $openFolderDialog.SelectedPath
		
		# Appel de la fonction qui affiche les projets
		affiche_projets
    }
})

# Gestion event quand on clique sur le bouton choisir
$button_ImagesPath.Add_Click(
{
    $openFolderDialog.Description      = "Selectionner le dossier des images"        
    $ret = $openFolderDialog.ShowDialog()

    if ($ret -ilike "ok") {
        $textbox_ImagesPath.Text = $openFolderDialog.SelectedPath
        $script:gns3_images_path_local = $openFolderDialog.SelectedPath
    }
})

# Gestion event quand on clique sur le bouton choisir
$button_TmpPath.Add_Click(
{
    $openFolderDialog.Description      = "Selectionner le dossier Temporaire"        
    $ret = $openFolderDialog.ShowDialog()

    if ($ret -ilike "ok") {
        $textbox_TmpPath.Text = $openFolderDialog.SelectedPath
        $script:temp_path = $openFolderDialog.SelectedPath
    }
})

# Gestion event quand on clique sur le bouton choisir
$button_ExportPath.Add_Click(
{
    $openFolderDialog.Description      = "Selectionner le dossier d'export"        
    $ret = $openFolderDialog.ShowDialog()

    if ($ret -ilike "ok") {
        $textbox_ExportPath.Text = $openFolderDialog.SelectedPath
        $script:export_project_path = $openFolderDialog.SelectedPath
    }
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