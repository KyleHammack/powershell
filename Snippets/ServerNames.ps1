$BaseName = "MyServer"

$Numbers = 1..20

Foreach ($Number in $Numbers) 
{
    $FullName = $BaseName + $Number.ToString("00#")
    
    $FullName
} 
