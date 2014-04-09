GLG Insite (Got-Names)
======================

A chrome extension to find names on web pages

##Private Key
To package the extension, by calling grunt package, a private key is needed.  This private key is not included in this repository.


##Building for AD Deploy
The AD deploy uses a generated .crx file located in 'origin/package'.  User browsers are updated automatically by periodically checking update.xml.

1.  If necessary, update the version number in manifest.json, update.xml, and package.json
2.  Run ```grunt package```
3.  Commit changes, merge to branch 'package', and push to 'origin/package'

The .crx extension file will be located in the /package folder of the project

##Building for Chrome Web Store Deploy
The Chrome Web Store Deploy uses an uploaded zipped dist folder.  User browsers are updated automatically by periodically checking the Chrome Web Store.

1.  If necessary, update the version number in manifest.json, update.xml, and package.json
2.  Run ```grunt prod```
3.  Open /dist/manifest.json and remove the update_url key/value pair
4.  Place all files and folders in the /dist directory into a .zip archive
5.  Log into the Google Developer Dashboard[chrome.google.com/webstore/developer/dashboard] with the appropriate credentials
6.  Click 'Edit' to edit the existing GLG Insite extension
7.  Click 'Upload Updated Package' and upload the .zip file created in step 3
8.  Click the 'Publish Changes' link at the bottom of the page

Pushing the extension live to the Chrome Web Store will require approximately 1 hour.  User browsers will then automatically over the next several hours unless additional permissions have been requested.
