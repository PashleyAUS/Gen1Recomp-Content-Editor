local F=assert(loadfile("tools/content-editor/Gen3FormsRuntime.lua"))()
local family={forms={{index=300},{index=443,mechanic={kind="mega",from=1}}}}
assert(F.savedMegaSource(family,443)==300)
assert(F.savedMegaSource(family,300)==nil)
family.forms[2].mechanic.kind="none"
assert(F.savedMegaSource(family,443)==nil,"Permanent forms must retain their identity")
family.forms[2].mechanic={kind="mega",from=2}
assert(F.savedMegaSource(family,443)==nil,"Self references must not be rewritten")
family.forms[3]={index=444,mechanic={kind="mega",from=1}}
assert(F.savedMegaSource(family,444)==300,"Multiple Mega results must use their configured source")
print("PASS: saved Mega species recover their source; permanent forms remain unchanged")
