Dears, Li Li,

Sorry... My computer only has Ubuntu OS and cannot type Chinese. So I write an introduction in English.
:(

Step 1. Generate ssh-key and copy it into the server (Ask Siqi Chen)
Step 2. Run our script. The usage of our script is 

Usage: run.sh <SERVER-IP-ADDRESS>

It will automatically detect the interface that has been allocated an IP address. It support to randomly choose <file>, <congestion-control>, <receiving-buffer-size>, <transmitting-buffer-size> and <scheduler>. All the configuration is written in the <settings> directory.

But it has a bug right now that the server cannot generate the throughput file. I think I can fix it later today.

And the file-formation is shown below:

#id.year.month.day.hour.minute.second.nanosecond
  |
  +- .config
  |
  +- wlan0
  |  |
  |  +- IP.pcap
  |  |
  |  +- throughput.log
  |  |
  |  +- .config
  |
  +- wlan1
     |
     +- IP.pcap
     |
     +- throughput.log
     |
     +- .config
     
For each random test, we will create a directory with style <id.year.month.day.hour.minute.second.nanosecond>. And in the directory, there are two parts of files, one is <.config> file which is used to record the testify configuration such as file-size, congestion-control, rx-buf, tx-buf and scheme.

The other is some directories named with interfaces. It will record the result for each interface. In each directory, there are 3 files, <.pcap>, <throughput.log> and <.config>. The <.pcap> file is named with its IP address and record the captured packets. <throughput.log> file is used to record the rx-byte, rx-packet, tx-byte and tx-packet. <.config> file is used to record the interface IP, the starting and the ending time.

I think Siqi Chen can handle this script. If you cannot contact with me, you can ask for Chen for the details.

Yours,

Xiangxiang Wang

2016-12-23