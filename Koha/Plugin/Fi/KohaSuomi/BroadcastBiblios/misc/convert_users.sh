#!/bin/bash

# Path to the file of users
users_file=$1
interface=$2

# Path to the file of users in the format of Koha

while IFS= read -r line; do
    # Process each line of the file here
    username=$(echo "$line" | cut -d',' -f1)
    password=$(echo "$line" | cut -d',' -f2)
    perl ./add_user.pl --username "$username" --auth_type basic --broadcast_interface "$interface" --password "$password"
done < "$users_file"
