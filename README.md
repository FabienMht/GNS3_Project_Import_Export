# GNS3_Project_Import_Export
Scripts d'import et d'export de projets sous GNS3.

Le script requiert :

	- GNS3 Version 2.0.3 (A essayer sur d'autres versions)
	- Windows 10,8.1,7
	- Hyperviseur Vmware Workstation et VirtualBox
	- Putty

## Fonctionnalités du script d'export et d'import
Export/Import des projets GNS3 :

    - Export/import des fichiers du projet contenues dans la VM GNS3 et en local
	- Export/import des machines virtuelles du projet
    - Export/import des images du projet
    - Fonctionnalités de GNS3 supportées :
    
    	- QEMU [x]
    	- IOS [x]
    	- DOCKER [x]
    	- IOU [x]
    	- Cloud [x]
    	- NAT [x]
    	- VM Vmware [x]
    	- VM Vbox [X]

	- Arborescence de l'export :
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
			
## Utilisation du script d'export et d'import

**Il faut modifier les variables du script en faisant correspondre les bons chemins.**

**Les images des noeuds du projet doivent être présentes sur le serveur local.**

**Il faut également que Putty soit installé et que son chemin soit dans le Path.**

### 1. Script d'export

Inclut par défaut les Vms et les images avec le projet :
> ./Nom du script
   
Pour ne pas inclure les images et les Vms dans l'export du projet :
> ./Nom du script -IncludeVms $false -IncludeImages $false
	
Pour lancer le script et définir les variables en ligne de commande sans modifier le script :
> ./Nom du script -ProjectPath "Path" -ImagesPath "Path" -IPGns3vm "Ip de la VM GNS3" -TmpPath "Path" -ExportPath "Path"
	
### 2. Script d'import

Inclut par défaut les Vms et les images avec le projet :
> ./Nom du script

Pour lancer le script et définir les variables en ligne de commande sans modifier le script :
> ./Nom du script -ProjectPath "Path" -ProjectZip "Path" -IPGns3vm "Ip de la VM GNS3" -VmwareVmFolder "Path" -TmpPath "Path"