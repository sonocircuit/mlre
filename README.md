# mlre

This an adaption of tehn's mlr script.

At first this started as a personal project to learn to code in lua (well to code in general actually). As I started to understand a bit more about the architecure and basics of norns scripts and softcut, many ideas came to mind, which I wanted to implement in mlr (because it is my favourite and most used script). These additional features are built around the original script, so the core of mlr remains unchanged.

I'd like to point out that there might be some bits of code that probably are messy/redundant or features that could be coded more efficiently/elegantly. PR's are welcome.

Also, this wouldn't have been possible without the countless contributions made by many members of ////////! Studying other scripts and comments on forum and discord channel have been, and will continue to be, a immense source of knowlage!

A special thanks to **tehn** for creating mlr and **zebra** for softcut and answering questions, **justmat** for hnds and bits of code (otis) and **infiniate digits** for bits of code (oooooo), answering questions and sparking ideas.


**TODO:**
- [ ] cleanup code

# Documentation:

## Grid Navigation
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/assets/grid_mlre_gridnav.png)

|**Button**|**Function**|**Button**|**Function**|  
|:---:|:---|:---:|:---|
|**REC view**|Set grid to REC page|**STOP ALL**| Stop all playing tracks| 
|**CUT view**|Set grid to CUT page|**MOD**| Modifier for different functions (see COMBOS)|
|**TRSP view**|Set grid to TRANSPOSE page|**Q**| Quantize grid presses (ON/OFF)|
|**LFO view**|Set grid to LFO page|**ALT**|ALT button for differnt functions (see COMBOS)|

|**COMBO**|**Function**|
|:---:|:---|
|**ALT + Q**|Set grid to CLIP page| 
|**ALT + REC view**|Clear softcut buffer (for all tracks)| 
|**ALT + MOD**|Set all playing tracks to step 1|  
|**ALT + STOP ALL**|Alt run (see Rec Page)|  
|**MOD + TRACK POSITION**|**HOLD MODE:** LOOP set to one single step (see CUT Page). To lock HOLD MODE press **MOD + ALT** and release **MOD before ALT**. Press **ALT** to unlock.|  
 
 **PATTERNS:**
- Description here

**RECALL:**
- Description here

 
## REC Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/assets/grid_mlre_recview.png)


|**GRID**| **Description**|
|:---:|:---|
|**A:**| **Activate Recoding** for tracks 1-6. Alt + rec arms a track for oneshot recording (see oneshot recording).|
|**B:**| **Track focus** for tracks 1-6. Alt + focus maps track tempo to system clock. This is indicated when all four leds are bright.|
|**C:**| **Track reverse** for tracks 1-6. If on, track playback direction is reversed.|
|**D:**| **Track speed** for tracks 1-6. Left from center / 8, / 4, / 2. Center position is speed = 1. Right from center * 2, * 4, * 8.|
|**E:**| **Activate Play** for tracks 1-6. Alt + play puts track in select mode (see select mode).|
|**F:**| **CUT view of focused track**|     

**Oneshot Recording:**  
When oneshot is activated for a track, recording will be automatically triggered when the threshold specified in the global parameters "rec thershold" is reached. Recording will be deativated for that specific track after one cycle.  

**Track select mode**  
When a track is in "select mode" the according LED will be lit slightly brighter than the others. These tracks respond to two things that non-selected tracks don't:  
- MIDI start message
- Alt Run Combo. When **ALT + STOP ALL** is pressed, playing tracks will stop and stopped tracks will play.


## CUT Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/assets/grid_mlre_cutview.png)



## TRANSPOSE Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/assets/grid_mlre_trspview.png)



## LFO Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/assets/grid_mlr_lfoview.png)


## CLIP Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/assets/grid_mlr_clipview.png)
