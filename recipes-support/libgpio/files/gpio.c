/*
	Copyright (C) 2015 Vibi Sreenivasan <vibisreenivasan@gmail.com>

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation version 2.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses>.
*/
#include "debug.h"
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <stdbool.h>
#include "libgpio.h"

#define MAX_GPIO_NUM 127
#define DIR_IN 1
#define DIR_OUT 2

static long gpio_num, gpio_value = -1, pulse, pulse_count = 100;
static int dir = DIR_OUT;
static bool read_gpio = false;
static bool write_gpio = false;

static void usage(char *s)
{
	info("Usage : \n");
	info("%s -p [gpio number] -[d|h|g|t|] -[s|c]\n", s);
	info("\t -p : gpio number\n");
	info("\t -h : help\n");
	info("\t -t : create pulses on the gpio\n");
	info("\t -c : number of pulses to create on the gpio\n");
	info("\t -g : get the value of an input gpio\n");
	info("\t -d : turn on debug\n");
	info("\t -s [gpio value] : set output to the gpio value (must be 0 or 1)\n");
	info("\t example: gpio -p 107 -s 1)\n");
	return;
}

static int parse_args(int argc, char **argv)
{
	int opt;
	while ( (opt = getopt(argc, argv, "gdhp:os:tc:")) != -1) {
		switch (opt) {
			case 'p' :
				gpio_num = strtol(optarg, NULL, 0);
				break;
			case 'g' :
				dir = DIR_IN;
                                read_gpio = true;
				break;
			case 'd' :
				__debug__ = 1;
				break;
			case 't' :
				pulse = 1;
                                write_gpio = true;
				dir = DIR_OUT;
				break;
			case 'c' :
				pulse_count = strtol(optarg, NULL, 0);
				break;
			case 's' :
                                write_gpio = true;
				gpio_value = strtol(optarg, NULL, 0);
                                if ((gpio_value < 0) || (gpio_value >1))
                                {
				  err("Incorrect Option %c[%d]\n", opt, gpio_value);
				  usage(argv[0]);
				  exit(5);
                                }
				break;
			case 'h' :
				usage(argv[0]);
				exit(0);
			default :
				err("Incorrect Option %c[%x]\n", opt, opt);
				usage(argv[0]);
				exit(2);
		}
	}
	return 0;
}

int validate_args(void)
{
	if (gpio_num > MAX_GPIO_NUM || gpio_num < 0) {
		err("gpio num %ld is greater than max allowed (%ld) \n", gpio_num, MAX_GPIO_NUM);
		exit(3);
	}

	if ((dir == DIR_OUT) && gpio_value == -1 && !pulse) {
		err("Value of gpio is required \n");
		return -1;
	}
	if ((read_gpio) && (write_gpio)) {
		err("Select either -s or -g, not both\n");
		return -1;
	}
	return 0;
}

static int dump_args(void)
{
	dbg("gpio number = %ld, dir = %d, gpio_value = %d\n", gpio_num, dir,
							gpio_value);
}

int main(int argc, char **argv)
{
	int ret = 0;
	gpio_t g;
        int value;
#ifdef DEBUG
        SET_DEBUG();
#endif
	if (argc < 2) {
		err("Incorrect Number of Arguments\n");
		usage(argv[0]);
		exit(4);
	}
	ret = parse_args(argc, argv);
	if (ret)
		return ret;
	ret = validate_args();
	if (ret) {
		err("Incorrect Arguments\n");
		usage(argv[0]);
		exit(5);
	}
	dump_args();

	g = gpio_aquire(gpio_num);
	if (!g) {
                // first try unexporting the gpio....
	        gpio_unexport(gpio_num);
                // try acquiring one more time
	        g = gpio_aquire(gpio_num);
	        if (!g) {
		  err("Unable to aquire gpio %ld\n", gpio_num);
		  exit(6);
                }
	}
	dbg("gpio %ld aquired\n", gpio_num);

	if (read_gpio) {
		int gv;
		ret = gpio_set_dir_input(g);
		if (ret) {
			err("Unable to set direction as input for gpio %ld\n", gpio_num);
		} else {
                        ret = gpio_get_value(g,  &value);
                        if (ret == 0)
                          printf("%d\n",value);
                        else
		          err("error getting value for gpio %ld\n", gpio_num);
		}

		goto release_gpio;
	} else {
		ret = gpio_set_dir_output(g);
		if (ret) {
			err("error setting direction for gpio %ld\n",
							 gpio_num);
			goto release_gpio;
		}
	}

	if (gpio_value != -1) {
		ret = gpio_set_value(g, gpio_value);
		if (ret) {
			err("error setting value for gpio %ld\n",
								gpio_num);
			goto release_gpio;
		}
                else
			dbg("setting gpio%d to %d\n",
						gpio_num, gpio_value);
	}

	if (pulse) {
		while (pulse_count--) {
			dbg("setting gpio%d value %d\n",
						gpio_num, pulse_count & 1);
			gpio_set_value(g, pulse_count & 1);
			usleep(1000);
		}
	}

release_gpio:
	gpio_release(g);
	dbg("gpio %ld released\n", gpio_num);
	return ret;
}
