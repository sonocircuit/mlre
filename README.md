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
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/resources/grid_mlr_gridnav.png)

|**Button**|**Function**|**Button**|**Function**|  
|:---:|:---|:---:|:---|
|**REC view**|Set grid page to REC page|**STOP ALL**| Stop all playing tracks| 
|**CUT view**|Set grid page to CUT page|**MOD**| Modifier for different functions (see COMBOS)|
|**TRSP view**|Set grid page to TRANSPOSE page|**Q**| Quantize grid presses (ON/OFF)|
|**LFO view**|Set grid page to LFO page|**ALT**|ALT button (see COMBOS)|

|**COMBO**|**Function**|
|:---:|:---|
|**ALT + Q**|Set grid page to CLIP page| 
|**ALT + REC view**|Clear softcut buffer (for all tracks)| 
|**ALT + MOD**|Set all playing tracks to step 1|  
|**MOD + TRACK POSITION**|**HOLD MODE:** LOOP set to one single step (see CUT Page). To lock HOLD MODE press **MOD + ALT** and release **MOD before ALT**. Press **ALT** to unlock.|  
 
 **PATTERNS:**
- Description here

**RECALL:**
- Description here

 
## REC Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/resources/grid_mlr_recview.png)

**A: Activate Recoding** for tracks 1-6. Alt + A arms a track for oneshot recording.   
**B: Track focus** for tracks 1-6. Alt + focus maps track tempo to system clock. This is indicated when all four leds are bright.   
**C: Track reverse** for tracks 1-6. If on track playback direction is reversed.  
**D: Track speed** for tracks 1-6. Center position is speed = 1. Left from center x2, x4, x8. Right from /2, /4, /8.   
**F: CUT view of focused track**     

## CUT Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/resources/grid_mlr_cutview.png)



## CLIP Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/resources/grid_mlr_clipview.png)



## LFO Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/resources/grid_mlr_lfoview.png)
