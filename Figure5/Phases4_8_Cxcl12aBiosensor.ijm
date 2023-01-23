//3 Jan 2023
//CBI Image Processing CRouviere
//Plugins necessaires : MorpholibJ et Log3D: http://bigwww.epfl.ch/sage/soft/LoG3D/
//This version run phases after cellpose segmentation process
//version 8.1 CR le 06/09/22 
//Begin after cellpose extraction
//changes : add a new Phase4 more efficient (Phase4new)
//			phase4new return a parameter
//			Phase7 remove cell without Spots and create a Lut
//			after phase 7 call FISH_PROG_PhaseMesureIntensity_Only_Ver20.ijm
//			add prints in log file
//			run all phases
//			Mesure-itensity function : change type to 8bite ans mesure Mean in place of intden
//			change mesure-intensity to a new function with one parameter
//			phase 4new et phase7 ont changees
//			Mesure_intensité : add luts
//			Phase8 add in comment possibility to add intensity of more than one spots
//			Mesure intensity function: add all spots intensities in the same Cell
//			retain pathtoSave
//			After Phase4New : save bassin-filtered image
//ATTENTION MAX ! number of spot and max intensity respectively fixed to  150 and 8000
//			Add an ROI choice
//			change lut "physics" to"Rainbow RGB"

var width1, height1, depth1, unit1;
//Notes for Segmentation
//
//Conseil pour lancer Cellpose apres le filtrage:
//Chercher l'image ayant la plus haute intensité, regler le contraste puis
//changer le stack en 8 bit (type 8 bits)
//Modifier le stack de facon a le rendre transformer en resolution homotétique:
//trouver le facteur proportionnele entre Z et X (ou Y) et augmenter le nbre de plans z en conséquence
//utiliser Image-Adjust-size mode bicubique
//utiliser "Cellpose" pour obtenir les volumes des cellules labellisées
//retablir le nbre de Z comme a l'origine avec Image-Adjust-size mode none (sans interpolations)

//close images and non image windows
run("Close All");

list = getList("window.titles");
     for (i=0; i<list.length; i++){
     winame = list[i];
      selectWindow(winame);
     run("Close");
     }
     
     run("ROI Manager...");
roiManager("reset")
//run("Record...");
//___________________________________BEGIN___________________________________________

//phase4New

	Dialog.createNonBlocking("Phase4new: filtrage sur volume des cellules");
	Dialog.addString("Experimentation name(short ! : will be added to the saved file )", "WT-Time1");
	Dialog.addMessage("Veuillez charger l'image des Labels issue de la segmentation des cellules");
  	Dialog.addMessage("");
  	Dialog.addMessage("AND , Please Draw an ROI above the région of interest with : freehand selection tool)");
  	Dialog.addMessage("than press OK when finished...");
	Dialog.show();
	expe=Dialog.getString();
	
//keep only ROI
if(Roi.size==0)
	exit("need a selection!");
roiManager("Add");
roiManager("Select", 0);
roiManager("Rename", expe);
setBackgroundColor(0, 0, 0);
run("Clear Outside", "stack");
run("Select None");
			
//keep image path in memory
pathtoSave=getDirectory("image");
rename("ADD-catchment-basins.tif");	
nBassin=Phase4New();
print("Phase4New : "+nBassin+"   Cells found");
if(nBassin>255)
	print("Warning: more than 8bits label for bassins !");
	
//sauvegarde des bassins filtres afin d'avoir une ref pour position des cellules	
saveAs("Tiff", pathtoSave+File.separator+"bassin-filtered.tif");
	
//phase5 log3D detections des spots  avant phase6 : 3D object Counter
	Dialog.createNonBlocking("Phase5, 6 et 7 : Analyse Spots");
	
	Dialog.addMessage("Veuillez charger l'image 561 nm des marquages de la proteine d'interet");
	Dialog.addNumber("Donner ici la proportionalité du voxel (rapport entre X,Y et Z)", 3);
	Dialog.addMessage("cliquer sur l'image acquise à 561 nm");
	Dialog.show();
	
	p=Dialog.getNumber();
//keep only ROI
roiManager("Select", expe);
setBackgroundColor(0, 0, 0);
run("Clear Outside", "stack");
run("Select None");	
//setBatchMode(true);
Phase5(p,70);//parametre =prominence pour image 32 bits issue de Log3D de Daniel Sage :http://bigwww.epfl.ch/sage/soft/LoG3D/
//setBatchMode(false);

//phase6 : 3D object counter
Phase6();

//phase7 identification spots versus cells, m is the total number of Spots
m=Phase7(nBassin);
print("Phase7 max spots :"+m);

//phase 8
	Dialog.createNonBlocking("Phase8 (last): Analyse intensite des Spots");
	Dialog.addMessage("Veuillez charger la table Results-Ph7 des marquages de la proteine d'interet");
	Dialog.addMessage("Veuillez charger l'image 561 nm \"561.tif\"des marquages de la proteine d'interet");
	Dialog.addMessage("ATTENTION: l'image 561 nm devant être 8bits: Elle va être typé 8 bit automatiquement pour cette phase!");
	Dialog.addMessage("");
	Dialog.addMessage("Et la sélectionner en cliquant dessus!");
	Dialog.show();
	
//keep only ROI
roiManager("Select", expe);
setBackgroundColor(0, 0, 0);
run("Clear Outside", "stack");
run("Select None");	

setBatchMode(true);
rename("561.tif");
run("8-bit");
//Table.rename("Results-Ph7.csv", "Results-Ph7");
setBatchMode(false);
MaxIntensite=Mesure_intensite(nBassin);
print(" max intensity="+MaxIntensite);

//add 2 columns in "Results-Ph8"
selectWindow("Results-Ph8");
for (i = 0; i < Table.size; i++) {
	v=Table.get("SpotInCellsCount", i);
	t=Table.get("CellIntensity", i);
	v=floor((v*255)/m);
	t=floor((t*255)/MaxIntensite);
    Table.set('SpotInCellsCountPondere', i,v);  
    Table.set('CellIntensityPondere', i,t);  
}
Table.update;


//save "Results-Ph8"
selectWindow("Results-Ph8");
saveAs("Results", pathtoSave+expe+"_Results-Ph8.csv");
selectWindow("Log");
saveAs("Text", pathtoSave+expe+"_Log.txt");

run("Tile");
run("Synchronize Windows");
selectWindow("bassin-filtered.tif");
setSlice(floor(nSlices/2));
run("Brightness/Contrast...");
run("Enhance Contrast", "saturated=0.35");

//___________________________________________END__________________________________________________

exit("Process, ALL, is finished,");
print("Please save your files");

//------------------------------------------FUNCTIONS--------------------------------------------

function Phase4New() {
	//ver1.0
	// Filtrage des cellules en fonction de leur volume 
	// in: image "ADD-catchment-basins" 16 bits labels obtenus via Cellpose
	// out : image "bassin-filtered" 16 bits et tableau des coordonnées des centroïdes des cellules et leur volume (results-Ph4)
	//       (Label,Volume,X_Centroid,Y_Centroid,Z_Centroid)
	//		Return the number of bassins
	//last changes :run("Remap Labels"); en commentaire pour l'instant,permet peut etre de travailler sur moins de 255 labels...
	
	print("Phase4New : Label images is filtred by CellVolume, and remaped");
	selectWindow("ADD-catchment-basins.tif");
	if(bitDepth()!=16)
		exit("Phase4: 16 bits needed");
	
	// Filtration du volume (diam géodésique = super long !)
	Dialog.createNonBlocking("Filtration du volume des cellules");	
	Dialog.addMessage("Veuillez choisir le volume maximale d'une cellule :");
	Dialog.addSlider("Volume maximale (pixel) : ", 5000, 100000, 80000);	
	Dialog.addMessage("Veuillez choisir le volume minimale d'une cellule :");
	Dialog.addSlider("Volume minimale (pixel) : ", 5000, 100000, 10000);
	Dialog.show();
	
	volumeMax = Dialog.getNumber();
	volumeMin = Dialog.getNumber();	
	
	run("Label Size Filtering", "operation=Greater_Than size="+volumeMin);	
	run("Label Size Filtering", "operation=Lower_Than size="+volumeMax);
	rename("bassin-filtered.tif");
	
	close("\\Others"); // Ferme tout sauf "bassin-filtered.tif"
	run("Remap Labels"); //si on veux renumeroter les label et essayer d'etre en 8 bits pour mettre une lut
	//count the number of labels
	setBatchMode(true);
	run("Z Project...", "projection=[Max Intensity]");
	getStatistics(area, mean, min, max);
	close();
	setBatchMode(false);
	return max;
}

function Phase5(propor,p) {

	// Prominence p can be change in  function of image quality
	// Macro qui execute un find Maxima pour toutes les images d'un stack
	// Il s'agit de l'ancienne macro :"Finddaxima-dilateOnStack.ijm "
	// in: ouvrir l'image acquise sur canal 561 nm qui contient, outre les contours, mais les dots a repérer.
	// out : image stack des dots nommée: "Stack" en binaire
	//Changes:	Log of gaussien 3D Daniel Sage-EPFL
	//			keep 1bit image
	//			Add a parameter for proportionality need in in Log3D
	
	print("Phase5 : On Spots'image : 2D Maximum local localisation");
	getDimensions(width, height, channels, slices, frames); // Returns the dimensions of the current image
	
	//run 3D log of gaussien detector from Daniel Sage, need to wait until the process is finished!
	run("LoG 3D", "sigmax=1 sigmay=1 sigmaz="+propor+" displaykernel=0 volume=1");
	list=getList("image.titles");
	n=list.length;
	m=n;
	while(m==n) {
		wait(100);
		list= getList("image.titles");
		m=list.length;
		showStatus("please wait, Log3D is running...");
	}
	showStatus("log3D finished!");

	run("Invert", "stack");	
	
	n = nSlices; // Returns the number of images in the current stack
	name = getTitle();
	setBatchMode(true);
	for(i = 1; i <= n; i++) {
		selectWindow(name);
		setSlice(i); // Affiche la iième tranche de la pile active
		run("Find Maxima...", "prominence="+p+" output=[Single Points]");
		}
		
	// Make stack from image named with "Maxima"
	
	run("Images to Stack", "method=[Copy (center)] name=Stack.tif title=Maxima use"); // Images to Stack
	run("Options...", "iterations=1 count=1 black do=Dilate stack");
	setBatchMode(false);
	selectWindow(name);
	close();
}

function Phase6() {

	// Utilise la methode 3D object counter de Fabrice Cordelière.
	// This macro will find all centroid in 3D, and display a Results tab with they coordonnates.
	// in: image open of dilated maximas get from phase 5
	// out: Results tab with maximas coordonates (Results)
	//		(X,Y,Slice)
	
	print("Phase6 : After Phase5 find 3D Maximum local localisation with 3D object counter");
	wait(1000);
	selectWindow("Stack.tif");
	rename("origine");
	run("Set Scale...", "distance=0 known=0 unit=pixel");
	run("3D Objects Counter", "threshold=128 slice=48 min.=3 max.=64995840 centroids");
	selectWindow("Centroids map of origine");
	setThreshold(1, 65535); // Définit les niveaux de seuil inférieur et supérieur
	setOption("BlackBackground", true); // Active / désactive l'option "Fond noir"
	run("Convert to Mask", "method=Default background=Dark black");
	run("Set Measurements...", "centroid stack redirect=None decimal=3");
	run("Analyze Particles...", "pixel display clear stack"); // Création du tableau Results_2.csv avec les coordonées des clusters en pixel
	selectWindow("bassin-filtered.tif");//from Phase 4
	close("\\Others");

}

function Phase7(nB) {
	//version 3.1
	// Scan Results tab with X,Y and Slice and add a column with the corresponding Cell label for each X,Y position
	// in  : image stack "bassin-filtered.tif" : stack of cell in gray level labeled and size filtered (from phase 4)
	//		"Results" tab with X,Y coordonates and Slice position
	// out : Results-Ph7 is created (from Results tab) with one more colomn 
	//		"Cellnumber" for the label index of Cells containing at least one spot	 
	//		Image "bassin-filtered.tif" still there
	//		Results-Ph8 is created, with a column containing the Number of spots by Cell (SpotCellsCount)
	//Changes:	nB is the nbre of bassins in "run("Z Project...", "projection=[Max Intensity]");
	//			Assign measure to label
	//			Add LUT on final image
	//			
	
	print("Phase7 : Count and localise Spots in labelled Cells");
	nbreOfCellWithClusters=0;
	selectWindow("bassin-filtered.tif");
	
//This part fill a new column with CellNumber	
	for (row = 1; row < nResults; row++) {	//LAST Changes
		x = floor(getResult("X", row));
		y = floor(getResult("Y", row));
		setSlice(floor(getResult("Slice", row)));
		setResult("CellNumber", row, getPixel(x, y));
	}
	updateResults();
	
// This part count for each cell the number of spots included in each cell
	SpotInCellsCount = newArray(nB+1);//max of bassins filtered
	Array.fill(SpotInCellsCount,0); // Initialisation to 0 

	for (row = 0; row < nResults; row++) { // Compte le nombre de cluster / CellNumber
		a = getResult("CellNumber", row);
		if(a!=0)
		SpotInCellsCount[a]++;
		nbreOfCellWithClusters++;
	}
	Array.getStatistics(SpotInCellsCount, min, max, mean, stdDev);
	//modification in ver 7.12 max is fixed to 150->100 3Jan2022
	max=100;
	IJ.renameResults("Results","Results-Ph7");
	//"Results-Ph8" tab is created here	
	order = Array.getSequence(nB+1);
	label=Array.deleteIndex(order, 0) ;
	Array.show("Nb_cluster_by_cell.csv",label,SpotInCellsCount);
	Table.rename("Nb_cluster_by_cell.csv","Results-Ph8");
	print("Phase7 : Prepare LUT for density representation");
	
	//Morpholibj
	selectWindow("bassin-filtered.tif");
	run("Assign Measure to Label", "results=Results-Ph8 column=SpotInCellsCount min=1.000 max="+max);
	//prepare to LUT Physics
	run("Multiply...", "value=255 stack");
	run("Divide...", "value="+max+" stack");
	setMinAndMax(0,255);
	run("8-bit");
	//run("physics");
	run("Rainbow RGB");
	run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal=0 font=12 zoom=1.3 overlay");
	print(nbreOfCellWithClusters+" spots counted");
	return max;
}


function Mesure_intensite(nB) {

	// Mesure l'intensitée de chaque cluster contenue dans une cellule Vers2.0
	// in  : Results-Ph7 (de phase7) et l'image acquise sur canal 561 nm qui s'apelle "561.tif"
	//		 and Results-Ph8 (de phase7)
	// out : "Results_-Ph8" avec une colonne des intensitées (CellIntensity) des clusters rajoutés
	//		0 : pas de spots detectés, ou bien un spot a deja ete analyse dans la meme zone 20x20 pixels
	//		 (X_Cluster,Y_Cluster,Z_Cluster,CellNumber,Intensity)
	//changes :	add all spots intensities in the same Cell
	

	print("Phase8 : Mesure spots intensity");
	run("Colors...", "foreground=white background=black selection=yellow");
	selectWindow("561.tif");
	selectWindow("Results-Ph7");
	nombre_ligne = Table.size;
	intensite=newArray(nombre_ligne);	
	CellNumberInt=newArray(nB+1);
	Array.fill(CellNumberInt,0); // Initialisation du tableau à 0 
	
	selectWindow("561.tif");
	run("Add...", "value=1 stack"); // On ajoute +1 à toutes les valeurs de pixel pour éviter d'en avoir un noir
	
	for (row = 0; row < nombre_ligne; row++) {
		showProgress(1, nombre_ligne);
		
		selectWindow("Results-Ph7");
		// Prend les valeurs dans les colonnes X, Y et Z (Slice) à la ligne row
		x = Table.get("X", row);
		y = Table.get("Y", row);
		z = Table.get("Slice", row);
		Spot_in_cell = Table.get("CellNumber", row);
		
		if (Spot_in_cell != 0) { // Si les coordonnées du cluster sont dans une cellule

			selectWindow("561.tif");
			setSlice(z);
			valeur_pixel_cible = getValue(x, y);
			
			if (valeur_pixel_cible != 0){ // On a pas encore compté ce cluster
				// On applique -11 sur les x et y pour centrer le cercle autour du cluster
				makeOval(x-11, y-11, 20, 20); // Crée un cercle autour de chaque spot (prend en entrée des pixels)
				run("Duplicate...", "title=1");
				run("Clear Outside");
				List.setMeasurements("limit");
 				Valeur_intensite=round(List.get("Mean"));
				close();

				//intensite[row]=round(Valeur_intensite);
				//CellNumberInt[Spot_in_cell]=round(Valeur_intensite);//Here: if 2 spots are in the same cell only the last intensity will be preserved !
				CellNumberInt[Spot_in_cell]=CellNumberInt[Spot_in_cell]+round(Valeur_intensite);//Here : we want add all spots intensities in the same Cell
				setForegroundColor(0, 0, 0);
				selectWindow("561.tif");
				run("Fill", "slice"); // Marque le cluster qui vient d'être mesurer en noir (0,0,0)
				}
			
			}
	
	}
	
//Table.setColumn("Intensity", intensite);
	//erase and update
	Table.update;
	selectWindow("561.tif");
	close();
	selectWindow("Results-Ph8");
	Table.setColumn("CellIntensity", CellNumberInt);
	Table.update;
	
//Luts for intensity
selectWindow("bassin-filtered.tif");
print("Phase Mesure intensity : Prepare LUT for Intensity representation");
Dialog.createNonBlocking("Prepare for Lut on intensity");
Dialog.addMessage("La table Results-Ph8 doit etre ouverte avec sa nouvelle colonne \"CellIntensity\" ");
Dialog.addMessage("Ainsi que l'image \"bassin-filtered.tif\" ");
Dialog.addMessage("");
Dialog.addMessage("Et la sélectionner en cliquant dessus!");
Dialog.addMessage("Attention: en faisant varier le Brightness/Contrast...vous changerez la plage de couleurs!");
Dialog.show();
//Array.show("array intensite avant lut", intensite);
//Morpholibj
selectWindow("bassin-filtered.tif");
run("Assign Measure to Label", "results=Results-Ph8 column=CellIntensity min=1.000 max=255");
//prepare to LUT Physics
selectWindow("Results-Ph8");
intens=Table.getColumn("CellIntensity");
Array.getStatistics(intens, min, max, mean, stdDev);
//Intensity max fixed only in this version 7.12 - > 2000 
max=2000;
selectWindow("bassin-filtered-CellIntensity");
run("Multiply...", "value="+255+" stack");
run("Divide...", "value="+max+" stack");
setMinAndMax(0,255);
run("8-bit");

//run("physics");
run("Rainbow RGB");
run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal=0 font=12 zoom=1.3 overlay");
return max;
}
