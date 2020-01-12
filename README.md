# single-molecule-imaging-toolbox
A collection of MATLAB tools for single-molecule image time series analysis.

## GUI

Execute `ui = ExperimentViewer();` to open the GUI.

All data is now also accessible from the command window via `ui.*`.

## Basic Data Structure

* Experiment
    * Channels
        * Images (every image is an ImageStack, even if only one frame)
        * Spots
            * Location in Images
            * Time Series (e.g. z-projection through selected ImageStack)
        * Alignment to another Channel (e.g. via image registration)

## Basic Data Structure for `ui = ExperimentViewer();`

* ui.hExperiment
    * .hChannels(i)
        * .hImages(j)
            * .data
            * .fileInfo
        * .hSpots(j)
            * .xy
            * .tsData
                * .time
                * .data
        * .hAlignedToChannel
        * .alignmentTransform
