dinstaller
^^^^^^^^^^

This is a very basic D installer that:
 1. Downloads DMD 1.030 from the digital mars website and uncompresses it.
 2. Adds directories to the PATH environment variable.
 3. Creates start menu shortcuts to unstinsall everything and to go to the documentation.
 4. Adds an entry in the uninstall programs feature of Windows.

To compile the NSIS file you'll need:

 * NSIS compiler, from:
	http://nsis.sourceforge.net/Download

 * Nsisunz.zip, from:
	http://nsis.sourceforge.net/Nsisunz_plug-in#Download
	Unzip and copy the nsisunz.dll to the \Program Files\NSIS\Plugins directory.

 * EnvVarUpdate.nsh, from:
	http://nsis.sourceforge.net/Environmental_Variables:_append,_prepend,_and_remove_entries#Function_Code

 * Inetc.zip, from:
	http://nsis.sourceforge.net/Inetc_plug-in#Links
	Unzip and copy the inetc.dll to the \Program Files\NSIS\Plugins directory.


Both DmdZipPath and DmcZipPath may be absolute.

You can also declare these defines when invoking makensis, like:

makensis /DDownloadDmdZipUrl=whatever

but you'll need to remove the defines from the nsi file.

Originally written by Ary Borenszweig
