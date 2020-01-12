# single-molecule-imaging-toolbox
A collection of MATLAB tools for single-molecule image time series analysis.

## Basic Data Structures

* Experiment
    * Channels
        * Images (every image is an ImageStack, even if only one frame)
        * Spots
            * Location in Images
            * Time Series (e.g. z-projection through selected ImageStack)
        * Alignment to another Channel (e.g. via image registration)
