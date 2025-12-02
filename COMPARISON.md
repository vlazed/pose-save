# Preserving poses between TF2 physics overrides

This document compares how this addon preserves poses for the following two cases:

- Adding physics objects to a model, and
- Removing physics objects from a model.

## Physics overrides

Other than the default (**DEF**) physics, the comparison uses the following physics overrides:

- [TF2 Phys Override](https://steamcommunity.com/sharedfiles/filedetails/?id=106817451) (**TPO**)
- [TF2 Better Phys V2](https://steamcommunity.com/workshop/filedetails/?id=202241938) (**TBP**)
- TF2 Advanced Physics (from [Advanced TF2 Characters](https://steamcommunity.com/sharedfiles/filedetails/?id=2864741154)) (**TAP**)
- [TF2 Improved Physics V4](https://steamcommunity.com/sharedfiles/filedetails/?id=2611472753) (**TIP**)
- [Another TF2 Physics Override](https://steamcommunity.com/sharedfiles/filedetails/?id=3315493382) (**ATPO**)

## Addition

|![img](/media/addition/default%20(ref).png)|
|:-:|
|**Reference pose (DEF). This lacks a left hand physics bone, collar bones, and a neck.**|

|On|![img](/media/addition/default%20(ref).png)|![img](/media/addition/phys%20override%20(on).png)|![img](/media/addition/better%20phys%20v2%20(on).png)|![img](/media/addition/adv%20phys%20(on).png)|![img](/media/addition/improved%20phys%20v4%20(on).png)|![img](/media/addition/atpo%20(on).png)|
|-|:-:|:-:|:-:|:-:|:-:|:-:|
|**Off**|![img](/media/addition/default%20(ref).png)|![img](/media/addition/phys%20override%20(off).png)|![img](/media/addition/better%20phys%20v2%20(off).png)|![img](/media/addition/adv%20phys%20(off).png)|![img](/media/addition/improved%20phys%20v4%20(off).png)|![img](/media/addition/atpo%20(off).png)|
|**Override**|Reference (DEF)|TPO|TBP|TAP|TIP|ATPO|

Adding physics models to a character offsets the pose significantly. Adding collar bones offsets the arms, as seen in the above images. The user must correct the arms. Comparing the poses with or without the addon, there is less correction work with the addon enabled.

## Subtraction

|![img](/media/subtraction/atpo%20(ref).png)|
|:-:|
|**Reference pose (ATPO). The neck, collar bones, and every spine bone has a physics object.**|

|On|![img](/media/subtraction/atpo%20(ref).png)|![img](/media/subtraction/phys%20override%20(on).png)|![img](/media/subtraction/better%20phys%20v2%20(on).png)|![img](/media/subtraction/adv%20phys%20(on).png)|![img](/media/subtraction/improved%20phys%20v4%20(on).png)|![img](/media/subtraction/default%20(on).png)|
|-|:-:|:-:|:-:|:-:|:-:|:-:|
|**Off**|![img](/media/subtraction/atpo%20(ref).png)|![img](/media/subtraction/phys%20override%20(off).png)|![img](/media/subtraction/better%20phys%20v2%20(off).png)|![img](/media/subtraction/adv%20phys%20(off).png)|![img](/media/subtraction/improved%20phys%20v4%20(off).png)|![img](/media/subtraction/default%20(off).png)|
|**Override**|Reference (ATPO)|TPO|TBP|TAP|TIP|DEF|

Subtracting physics models offsets the pose, but it is subtle compared to addition. Significant offsets are seen with the neck bone and the `bip_spine_3` bone (the last spine bone before the neck). Again, one can perceive less correction work with the addon enabled versus having it disabled.
