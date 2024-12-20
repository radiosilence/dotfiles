# display original year with fallback

```
['('$left($if2(%originaldate%,%date%),4)')' ]
```

Find things where originaldate and date dont match

```
$if(%originaldate%,$ifequal(%originaldate%,%date%,SAME,DIFF),NONE)
```

Find things where %date% and %releasedate% dont match

```
$if(%releasedate%,$ifequal(%releasedate%,%date%,SAME,DIFF),NONE)
```
