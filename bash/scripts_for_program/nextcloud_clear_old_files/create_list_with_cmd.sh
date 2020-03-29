#!/bin/bash
################################################################################
#                                                                              #
#                       Delete files after upgrade nextloud                    #
#                                                                              #
#                       mailto:dusharu17@gmail.com                             #
#                                                                   208.10.14  #
################################################################################
LIST_OF_FILES="$(dirname "$(realpath "$0")")/list_of_files"

sed -e '/- EXTRA_FILE/ d;' "$LIST_OF_FILES" | \
sed -e 's#^- core#cd /var/www/nextcloud/#' | \
sed -e 's#^- #cd /var/www/nextcloud/apps/#' | \
sed -e 's#              - #  rm -f #' | less
# ^I - CTRL+V + CTRL+I
