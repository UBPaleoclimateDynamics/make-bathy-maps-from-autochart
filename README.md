# make-bathy-maps-from-autochart

Need to make a bathy map from the files spit out by Autochart? :computer: :ocean: :world_map:

This repository contains codes written in R that use .kml and .tif files from Autochart (or Google Earth) to make nice maps of lake bathymetry. 

Two options: 

| Files you have  | | Code to use | 
| ------------- |-------------| ------------- |
| Grayscale Autochart .kml and .tif file | :arrow_right: | `BathymetryFromAutochart.R`| 
| Google Earth polygons as a .kml file, <br> where each polygon is named following <br> 'contour #m', where # is the depth | :arrow_right: | `BathymetryfromGoogleEarth.R`|

Example Grayscale Autochart .tif file.
<img src

Both codes will produce a bathymetry map, with contours colored by their depth. 
<img src="examples/RedPond-bathymetry.png" width = "500">

These maps can be overlaid on topography/LiDAR. <br>

<img src="examples/BearLake-AGU-example.png" width = "500">
