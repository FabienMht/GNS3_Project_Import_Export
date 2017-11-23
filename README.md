# GNS3_Project_Import_Export
Scripts d'import et d'export de projets sous GNS3.

Le script requiert :

	- GNS3 Version 2.0.3 (A essayer sur d'autres versions)
	- Windows 10 (A essayer sur d'autres versions 8.1,7)
	- Hyperviseur Vmware Workstation, VirtualBox ou QEMU pour les VMs
	- Putty

## Fonctionnalités du script d'export et d'import
Export/Import des projets GNS3 :

    - Ajout de la GUI pour les script d'import et d'export
	- Export/import des fichiers du projet contenues dans la VM GNS3 et en local
	- Export/import des machines virtuelles du projet
    - Export/import des images du projet
	- Cloner des machines virtuelles QEMU
	- Importation des images IOS,IOU,QEMU de la VM GNS3 dans le répertoire local des images de GNS3
	- Téléchargement automatique de putty si connexion internet
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

**1. Avec la GUI les étapes 2 et 3 sont gérées directement depuis l'interface !**

**2. Il faut modifier les variables du script en faisant correspondre les bons chemins.**

**3. Les images des noeuds du projet doivent être présentes sur le serveur local.**

**4. Il faut également que Putty soit installé et que son chemin soit dans le Path.**

### 1. Script d'export

Inclut par défaut les Vms et les images avec le projet :
> ./Nom du script
   
Pour ne pas inclure les images et ne pas archiver l'export du projet :
> ./Nom du script -ArchiveProjet $false -IncludeImages $false
	
Pour lancer le script et définir les variables en ligne de commande sans modifier le script :
> ./Nom du script -ProjectPath "Path" -ImagesPath "Path" -IPGns3vm "Ip de la VM GNS3" -TmpPath "Path" -ExportPath "Path"
	
### 2. Script d'import

Inclut par défaut les Vms et les images avec le projet :
> ./Nom du script

Pour lancer le script et définir les variables en ligne de commande sans modifier le script :
> ./Nom du script -ProjectPath "Path" -ImagesPath "Path" -ProjectZip "Path" -IPGns3vm "Ip de la VM GNS3" -VmwareVmFolder "Path" -TmpPath "Path"