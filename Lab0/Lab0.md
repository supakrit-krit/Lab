Lab0: Commands
=========

network setting
------

TODO

>Reference: 
>1.	https://www.cisco.com/c/en/us/td/docs/routers/access/800M/software/800MSCG/routconf.html

screen
------

Prior to Red Hat Enterprise Linux 8, the screen command was included. In version 8, the decision was made to deprecate screen and use tmux instead.

``` bash
sudo dnf install epel-release
sudo dnf install screen
screen -S test
screen -S test2
top
# Ctrl-a + d
screen -ls
screen -X -S test quit
screen -ls
screen -r test2
exit
screen -ls
```

Options:
-S sockname: It name this session .sockname instead of …
-r \[session]: It reattach to a detached screen process.
-ls [match]: It display all the attached screens.

Shortcut keys Options:
- Ctrl-a + d: It detach a screen session without stopping it.

>Reference: 
>1.	https://www.geeksforgeeks.org/screen-command-in-linux-with-examples/
>2. https://www.redhat.com/en/blog/tips-using-tmux
>3. https://www.youtube.com/watch?v=CGijY_aUvNs