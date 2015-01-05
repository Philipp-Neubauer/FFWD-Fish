FFWD-Fish
=========

Future Fisheries under climate change


Notes on deploying _site
------------------------

If deployment fails, it's probably due to remote changes in the gh-pages branch that need to be pulled into the master ```_site``` before it can be pushed to github. To fix this, a note to self: the ```_site``` directory is a subtree merge from the gh-pages branch, like so:
```git read-tree --prefix=_site/ -u gh-pages```

To pull in manual changes (say, made on github), to _site before re-deploying, do:
```git checkout gh-pages''' and ```git pull```. Of course.

Do: ```git diff-tree -p gh-pages``` to see changes.

Then, merge them into ```_site```: 
```git checkout master```
```git merge --squash -s subtree --no-commit gh-pages```