// Voir le Read.me
//Utiliser Fiji avec les plugins suivants : -Anomalous Diffusion Filters PlugIn : CSIM Laboratory : https://imagej.net/plugins/csim-lab -IJPB plugins pour MorpholibJ


var width1, height1, depth1, unit1;

Phase1();



function Phase1() {

	// Pré-traite le l'image du canal 488 
	// Attention le contraste doit etre suffisament élevé, fond autour de NG=10
	// in : Image avec le signal des contours ouverte (488 nm)
	// out: Même stack filtré

	setBatchMode(true); // Permet de gagner du temps en affichant pas les resultats à l'écran
	//open(chemin_image + nb[0]); // Ouverture de l'image avec le canal 488
	getVoxelSize(width1, height1, depth1, unit1); // resultat écrit en pixel
	run("Gaussian Blur...", "sigma=1 stack");
	run("Subtract Background...", "rolling=50 stack");
	run("Anisotropic Anomalous Diffusion 2D Filter", "apply anomalous=1.0000 condutance=15.0000 time=0.1250 number=5 edge=Exponential");
	rename("ADD.tif");
	setBatchMode(false);
}