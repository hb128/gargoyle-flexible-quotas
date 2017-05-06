# Introduction
With this small collection of bash scripts for the [Gargoyle
firmware](https://www.gargoyle-router.com/) you can dynamically adjust
free quotas hourly. This is useful for capped data plans. These throttle the
bandwidth if a specific amount of data is exceeded.
A monthly fixed quota for each user derived by dividing this total available
amount of data has disadvantages:
1. Any of one user unused quota cannot be used by the other users.
2. A user can (unintentionally) use all his quota at the beginning of the month
because he can.

To mitigate the last problem one could come up with the idea to set daily quotas.
Not alone does this not solve the first problem but it intensifies it. Each daily
unused quota decays at the end of each day and cannot be used on the following day
anymore.

This tool tries to tackle both problems:
At the beginning of the month it sets for each user a small quota.
To solve the second problem it runs hourly and increases all quotas a
little bit. Therefore the monthly quota cannot be used at once because it
is distributed evenly among the month, so the second problem is solved.
The first problem is solved by limiting the unused quota each user can save up
and distribute any exceeding quotas among the other users.
This limit is decreased at the end of the month to allow all users to make use
off the total amount of data available in the data plan.

# Setup
In this setup we are going to exemplary distribute a monthly amount 30 GB to
the users *Alice* and *Bob*.
## Add quotas
You need to add DHCP rules for all devices of both users. E.g.
192.168.1.5x for *Alice* and 192.168.1.6x for *Bob*.

In gargoyle GUI / Firewall / Quotas add new quotas. Set the parameters to:
```
Applies to: ip range, 192.168.1.50 - 192.168.1.59 (Alice) / 192.168.1.60 - 192.168.1.69 (Bob)
Max Total Up+Down: 100 MB (does not matter, will be set by the script)
Quota Resets: Every Month
Quota is Active: Always
When Exceeded: throttle bandwidth to a very low value
```

To prevent that any new devices are not sorted in these ip ranges and are therefore
not affected by the quotas, set the DHCP ip range to for example
192.168.1.100 - 192.168.1.250
and add a third quota rule which effectively stops internet usage for these devices:
```
Applies to: ip range, 192.168.100 - 192.168.1.250
Max Total Up+Down:1 kB (very low, won't be overwritten by the script)
Quota Resets: Every Month
Quota is Active: Always
When Exceeded: throttle bandwidth to a very low value
```

## Create config file
Clone this repository on your local machine, change to the repository
directory and create a config file *config.sh* from the example file
```bash
cp config-example.sh config.sh
```
Add/adjust then for each user lines like
```bash
user2="Alice"; iprange2="192.168.1.50-192.168.1.59"; monthly_quota2=$((20*gigabye))
user1="Bob"; iprange1="192.168.1.60-192.168.1.69"; monthly_quota1=$((10*gigabye))
```
**Do not forget to adjust nusers accordingly!**
There are some more settings like the maximal savings which may be useful to consider.
If you like to get a mail with the logs you should also have a look at the mail settings.

## Deploy script on router
Copy the git repository to the router (here the git config entry *gargoyle* is used):
```bash
scp *.sh gargoyle:~/gargoyle-flexible-quotas/
```
Establish a SSH connection to the router and run
```
crontab -e
```
and add this entry, to run the script every hour:
```bash
1 * * * * /root/gargoyle-flexible-quotas/update-quotas.sh > /root/flexible-quotas-hourly.log 2>&1
```
To email the logs make sure to add some email credentials to the config file and add
```
2 * * * * /root/gargoyle-flexible-quotas/send-mail-hourly.sh /root/flexible-quotas-hourly.log > /root/mailsend.log 2>&1
```

# Support
Please feel free to open an issue if you encounter any problems or have any feature requests.
