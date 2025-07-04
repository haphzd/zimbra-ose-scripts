# zimbra-ose-scripts
Maintenance scripts for Zimbra v8-v9 open source edition

## zm-compress-blobs.sh
Will process mail items in a store and gzip'em to save space. It doesn't matter if compression is enabled or disabled for a store being processed.  
Will skip briefcase files (binary or versioned).  
Messages sent to distribution lists are stored as one real copy for multiple users, use `--hardlinks` switch to compress them.  
Set variables for time period/size filtering before running. 
