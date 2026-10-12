package.path="tools/content-editor/?.lua;"..package.path
local F=require("Gen3Forms")
local f={forms={{species="SHIFTRY",name="Original"},{species="SHIFTRY_FORM_2",name="Mega"}}}
local s={g3FormSelection={SHIFTRY=1}}
assert(F.editSelection(s,f,"SHIFTRY","SHIFTRY_FORM_2")==2,"Species list must select the custom form")
s.g3FormSelection.SHIFTRY=1
assert(F.editSelection(s,f,"SHIFTRY","SHIFTRY_FORM_2")==1,"Explicit form dropdown choice must persist")
assert(F.editSelection(s,f,"SHIFTRY","SHIFTRY")==1,"Base species must select the base form")
assert(F.editSelection(s,f,"SHIFTRY","SHIFTRY_FORM_2")==2,"Returning to a custom species must select it again")
local other={forms={{species="TORKOAL"},{species="TORKOAL_FORM_2"}}}
assert(F.editSelection(s,other,"TORKOAL","TORKOAL_FORM_2")==2,"Switching families must follow the selected species")
assert(F.editSelection({},f,"SHIFTRY","SHIFTRY_FORM_2")==2,"Fresh editor state must follow the selected species")
print("PASS: form editor follows species selection and preserves explicit dropdown choices")
