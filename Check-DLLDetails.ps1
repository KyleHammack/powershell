$asm = [Reflection.Assembly]::LoadFile("C:\test.dll")
$asm.GetTypes() | select Name, Namespace | sort Namespace | ft -groupby 
Namespace