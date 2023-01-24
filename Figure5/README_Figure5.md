# How to use the Cxcl12a Biosensor Processing macro command.

## Requirements:
Use Fiji with the following plugins:   
Anomalous Diffusion Filters PlugIn: CSIM Laboratory: https://imagej.net/plugins/csim-lab   
-IJPB plugins for MorpholibJ

## Use : This program works with 488 images:  
This program works with images 488 (cell selections of interest) and 561 (signal of interest).  

## Operation:
This program is divided into several functions named phase1(), phase2(),...      
phase 1: Pre-processes the image of channel 488 (Anisotropic filter)
2 : Cellpose (Segmentation)  
3 : Cellpose (Cell pool extraction) 
phase 4: Filtering of the cells according to their surfaces + calculation of their volume  
phase 5: Extraction of Spots  
phase 6 : Cluster coordinates retrieval  
phase 7: Count the number of Spots per cell  
phase 8 : Intensity measurement of each Spot contained in each cell  
