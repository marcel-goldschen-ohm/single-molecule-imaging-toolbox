# single-molecule-imaging-toolbox
A collection of MATLAB tools for single-molecule image time series analysis.

## GUI

Execute `ui = ExperimentViewer();` to open the GUI.

All data is now also accessible from the command window via `ui.*` (see below).

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

## Basic Usage

1. Open the GUI by executing `ui = ExperimentViewer();`. This will show a default empty `Experiment`.
2. Create `Channel`s as needed by clicking the `+` button above the channels listbox.
3. For each channel, load images/image stacks via the channel's image menu (hamburger menu button near the top left corner of each channel's image axes - make sure the *Image* or *Image & Trace* layout is selected so that image axes are shown).
4. For each channel, select the image stack to use for z-projecting spots via the channel's trace menu (hamburger menu button near the top left corner of each channel's trace axes - make sure the *Trace* or *Image & Trace* layout is selected so that trace axes are shown).
5. Align channels as needed via the channel's image menu (see below).
6. Find the spots in a representative image for one of your channels (i.e. the image that most reliably shows spot locations) via that channel's image menu.
7. Copy the identified spots in the above channel to all other channels via that channel's image menu. When copied spot locations will be adjusted to account for the relative alignment between channels. Thus, if you alter channel alignments, you will need to repeat this step (:construction: this could be handled automatically, see TODO below).
8. Z-project all spots. Set selection to *all channels* (see Selections and Actions section below) and click the *Z-Project Traces* button.
9. Save the experiment data structure (File->Save). You can now load the data again via File->Open (however there is one gotcha that you will love, see the File I/O section below).

## File I/O

## Channel Alignment

1. To align channel A to channel B, open channel A's image menu by clicking the hamburger menu button near the top left corner of channel A's image axes (make sure the *Image* or *Image & Trace* layout is selected so that image axes are shown).
2. In the *Alignt To* submenu choose channel B (or *None* to remove any alignment).
3. Next select the alignment method from the dialog.
    * Images: Align by image registration. Uses MATLAB's imageRegistrationApp to register the currently visible images for channels A (moving) and B (fixed). Note, I have found the multimodal intensity based registration to be a good default choice, at least for the images I have tested it on. Also, reducing the radius prameter by a factor of 10-100 seems to be benefitial. Once you are happy with the registration, export it (the exported variable name is arbitrary, so you can just accept the default), and then close the app window. Upon closure of the registration app window the experiment viewer will find the exported registration and load it into the experiment data structure.
    * Spots: Align by spot registration. :construction: Not yet implemented, see TODO below.
    * Identity: Make sure channel A always has the same transformation as channel B.

## Selections and Actions

## Time Series Model Idealization

## Adding Custom Functions to the GUI

## TODO :construction:

* Spot drift correction. I have been lazy about this as my current setup has subpixel drift even over long experiments, so it's currently a nonissue for me. However, it may be important for other setups, so this functionality should be added to the toolbox for more general aplicability.
* Channel alignment by aligning spots rather than registering images.
* Update spot locations automatically on alignment change.
