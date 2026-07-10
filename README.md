# DevSpaces development process

To use DevSpaces to work on this project click on the link below.

[<img src=DevSpaces.png width=50>](https://devspaces.apps.ocp4.mr-openshift.co.uk/dashboard/#/load-factory?url=https://github.com/marrober/pacman.git)


## Clean packages spec :

  "dependencies": {
    "body-parser": "^2.2.2",
    "express": "^5.2.1",
    "mongodb": "^2.2.4",
    "_comment": "mongodb clean version is 7.2.0, and for an example with vulnerabilities use 2.2.24",
    "pug": "^3.0.4"
  },
  "devDependencies": {
    "nodemon": "^3.1.14"

## Old packages spec :

  "dependencies": {
    "body-parser": "^1.20.3",
    "express": "^4.14.1",
    "jade": "^1.11.0",
    "mongodb": "^2.2.24"
  },
  "devDependencies": {
    "nodemon": "^1.11.0"


## Combinations of images and packages

### Test 1
registry.access.redhat.com/hi/nodejs/latest
express - version 3.19.1

The above generates a small number of violations in the base (typically 1) and over 35 in the application layer.
The base image vulnerability doesn't currently show in the ACS view.

example : pacman-pr-qgr6b

### Test 2
registry.access.redhat.com/hi/nodejs/latest
express - version 4.21.2

The above generates violations only in the base (typically 1).
There are no vulnerabilities in the application layer.

example : pacman-pr-jtctq

### Test 3
default-route-openshift-image-registry.apps.ocp4.mr-openshift.co.uk/pacman-ci/nodejs:nodejs-22-9.8-178
express - version 4.21.2

### Older versions

From last week - this seemed to work
