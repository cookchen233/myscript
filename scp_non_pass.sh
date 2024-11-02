#!/usr/bin/expect

set ssh_accounts {
    "192.119.103.228" "RwvDdPCNGN2C6"
}

# Get the password of specifed ssh account through list type variable.
set password ""
set i 0
set j 0
foreach ssh_account $ssh_accounts {
    incr j
    if { $i == 0 } {
        # Skip the next list group
        if { $ssh_account == [lindex $argv 2] } {
            set password [lindex $ssh_accounts $j]
            puts "password is ok";
            break
        }
        set i 1
        continue
    } else {
        set i 0
    }
}

set timeout 30
# scp src_dir root@ip:dst_dir
spawn scp [lindex $argv 0] [lindex $argv 1]@[lindex $argv 2]:[lindex $argv 3]
expect {
        "(yes/no)?"
        {send "yes\n";exp_continue}
        "password:"
        {send "$password\n"}

}
interact
