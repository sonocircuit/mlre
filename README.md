# mlre


## work in progress



This an adaption of tehn's mlr script.

At first this started as a personal project to lean to code in lua (or to code in general). As I started to understand a bit more about the architecure and basics of norns scripts and softcut, many ideas came to mind, which I wanted to implement in mlr (because it is my favourite and most used script). These additional features are built around the original script, so the core of mlr remains unchanged.

I'd like to point out that there might be some bits of code that probably are redundant or features that could be coded more efficiently/elegantly. PR's are welcome.

Also, this wouldn't have been possible without the countless contributions made by many members of ////////! Studying other scripts and comments on forum and discord channel have been, and will continue to be, a immense source of knowlage!

A special thanks to **tehn** for creating mlr and **zebra** for softcut and answering questions, **justmat** for hnds and many bits of code and **infiniate digits** for bits of code, answering questions and giving me ideas.


**TODO:**
- [ ] cleanup code
- [ ] implement loop resize at rec end??
- [ ] oneshot mode??
- [ ] threshold rec??


# Documentation:

## Grid Navigation
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/resources/grid_mlr_gridnav.png)

**REC view:** Set grid page to REC page, norns to MAIN pages  
**CUT view:** Set grid page to CUT page, norns to MAIN pages  
**CLIP view:** Set grid page to CLIP page, norns to CLIP page  
**LFO view:** Set grid page to LFO page, norns to LFO pages  

**STOP ALL:** Stop all playing tracks  
**MOD:** Modifier for different functions (see COMBOS)  
**Q:** Quantize grid presses (ON/OFF)  
**ALT:** ALT button (see COMBOS)  

**PATTERNS:**
- Description here

**RECALL:**
- Description here

**COMBOS:**

**ALT + REC view:** Clear softcut buffer (for all tracks)  
**ALT + Q:** Time settings page (enc 2 -> tempo, enc 3 -> quantization division)  
**ALT + MOD:** Set all playing tracks to step 1  
**ALT + STOP ALL:** ALTRUN -> Stopped tracks play and playing track stop (For selected tracks only (see REC Page))  
**MOD + TRACK POSITION:** HOLD MODE -> LOOP set to one single step (see CUT Page). To lock HOLD MODE press **MOD + ALT** and release **MOD before ALT**. Press **ALT** to unlock.   



## REC Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/resources/grid_mlr_recview.png)



## CUT Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/resources/grid_mlr_cutview.png)



## CLIP Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/resources/grid_mlr_clipview.png)



## LFO Page
![grid navigation](https://github.com/sonoCircuits/mlre/blob/main/resources/grid_mlr_lfoview.png)
