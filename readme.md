<!-- README.md is generated from README.Rmd. Please edit that file -->
EastAntarctica\_Atlantis
------------------------

This repository stores in-progress data resources for developing an Atlantis model for East Antarctica.

### Obtaining / synching / working with this repository

1.  With RStudio:
    -   File/New Project/Version Control/Git
    -   Enter "<https://github.com/AustralianAntarcticDivision/EastAntarctica_Atlantis.git>"
    -   Click "Create Project"
    -   For updates click "Pull"

2.  With git on the command line:
    -   `git clone https://github.com/AustralianAntarcticDivision/EastAntarctica_Atlantis.git`
    -   `cd EastAntarctica_Atlantis`
    -   For updates `git pull`

3.  Use the "Issues" feature on this page to make requests, report bugs etc.

Content
-------

    manifold/  - workings in Manifold GIS
    old/       - old stuff
    versions/  - versions of artefacts as they are created

Resources
---------

We are using Manifold for now to modify input model topologies, via shapefiles.

### Antarctica\_28

`Antarctica_28` is a stripped down test domain with 28 Atlantis boxes (including boundary boxes).

In the directory is the source Manifold.map project, the shapefile/s and the generated .bgm.

    manifold/
    ├── Antarctica_28.bgm              - BGM file generated by bmeriser (see belog)
    ├── Antarctica_28.dbf/prj/shp/xml  - the shapefile (.xml is Manifold auxiliary file)
    └── Antarctica_28.map              - Manifold project used to edit the layer

Antarctica\_28.bgm generated with

`bash java -jar bgmeriser.jar -as "+proj=laea +lat_0=-63 +lon_0=82 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs +ellps=WGS84"  Antarctica_28.shp`

Antarctica\_28 was derived from Antarctica\_99

### Antarctica\_99

The shapefile and .bgm are in versions/antarctica\_99/

This was modified in QGIS, something, something . . .
