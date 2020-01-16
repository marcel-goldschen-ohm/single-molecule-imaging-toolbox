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

* ui.hExperiment: `Experiment` handle.
    * .hChannels(i): Array of `Channel` handles.
        * .hImages(j): Array of `ImageStack` handles (images are single frame stacks).
            * .data: [rows,columns,frames] image stack intensity values.
            * .fileInfo: Image file information as returned by `iminfo()`.
        * .hSpots(j): Array of `Spot` handles.
            * .xy: [x,y] location in image.
            * .tsData: `TimeSeries` object.
                * .time: Time array (e.g. image stack frame # or time).
                * .data: Data array (e.g. image stack spot intensity per frame).
        * .hAlignedToChannel: Handle to other `Channel` to which this channel is aligned.
        * .alignmentTransform: 2D transformation that aligns this channel to another channel.
