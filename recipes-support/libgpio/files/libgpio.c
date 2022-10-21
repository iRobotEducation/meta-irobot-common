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

#undef STATIC_BUILD_WITH_PTHREAD
#include "debug.h"
#include <stdio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#ifdef STATIC_BUILD_WITH_PTHREAD
#include <pthread.h>
#endif
#include "libgpio.h"

#define GPIO_DIR "/sys/class/gpio/"
#define EXPORT_FILE GPIO_DIR"export"
#define UNEXPORT_FILE GPIO_DIR"unexport"
#define GPIO_DIR_FORMAT_STR GPIO_DIR"gpio%d"
#define GPIO_PARAM_FORMAT_STR GPIO_DIR_FORMAT_STR"/%s"

#define MAX_NR_GPIOS 127

struct gpio {
	int gpio_num;
};

#ifdef STATIC_BUILD_WITH_PTHREAD
static pthread_mutex_t gpio_arr_lock = PTHREAD_MUTEX_INITIALIZER;
#endif

static gpio_t gpios[MAX_NR_GPIOS];

static int open_n_wrrd(int wr, char *filename, char *buf, int size)
{
	int ret = 0, fd, flags;

	if (wr)
		flags = O_WRONLY;
	else
		flags = O_RDONLY;

	fd = open(filename, flags);
	if (fd < 0) {
		err("Opening file %s failed\n", filename);
		return -1;
	}

	if (wr)
		ret = write(fd, buf, size);
	else
		ret = read(fd, buf, size);

	dbg("ret = %d\n", ret);
	if (ret < 0) {
		err("%s to file %s failed\n", wr ? "writing" : "reading",
								filename);
		ret = -1;
	} else
		ret = 0;
	close(fd);
	return ret;
}

static inline int open_n_write(char *filename, char *wstr, int size)
{
	return open_n_wrrd(1, filename, wstr, size);
}

static inline int open_n_read(char *filename, char *buf, int size)
{
	return open_n_wrrd(0, filename, buf, size);
}

static int export(int gpio_num)
{
	int ret = 0;
	char buf[1024];
	struct stat s;

	snprintf(buf, sizeof(buf) - 1, GPIO_DIR_FORMAT_STR, gpio_num);

	if (!stat(buf, &s)) {
		dbg("gpio %d already exported\n", gpio_num);
		return ret;
	}
	snprintf(buf, sizeof(buf) - 1, "%d", gpio_num);
	ret = open_n_write(EXPORT_FILE, buf, strlen(buf));
	return ret;
}

static int _direction(int set, int gpio_num, char *sdir)
{
	int ret = 0;
	char buf[1024];

        snprintf(buf, sizeof(buf) - 1, GPIO_PARAM_FORMAT_STR, gpio_num,
						"direction");

	if (set)
		ret = open_n_write(buf, sdir, strlen(sdir));
	else
		ret = open_n_read(buf, sdir, 3);
	return ret;

}

static int _value(int set, int gpio_num, char *sval)
{
	int ret = 0;
	char buf[1024];

	snprintf(buf, sizeof(buf) - 1, GPIO_PARAM_FORMAT_STR, gpio_num,
							"value");
	if (set)
		ret = open_n_write(buf, sval, 1);
	else
		ret = open_n_read(buf, sval, 1);
	return ret;
}

void gpio_release(gpio_t g)
{
	gpio_t gf = NULL;
	char buf[1024];

	if (!g) {
		err("Incorrect Argument");
		return;
	}
	dbg("releasing gpio %d\n", g->gpio_num);
	snprintf(buf, sizeof(buf) - 1, "%d", g->gpio_num);
#ifdef STATIC_BUILD_WITH_PTHREAD
	if (!pthread_mutex_lock(&gpio_arr_lock)) {
#endif
		if (gpios[g->gpio_num] == g) {
			gpios[g->gpio_num] = NULL;
			open_n_write(UNEXPORT_FILE, buf, strlen(buf));
			gf = g;
		}
#ifdef STATIC_BUILD_WITH_PTHREAD
		pthread_mutex_unlock(&gpio_arr_lock);
	}
#endif
	if (!gf)
		err("FATAL ERROR - CORRUPTED GPIO DESCRIPTOR: gpios[%d] = %p,"
				" %p\n", g->gpio_num, gpios[g->gpio_num], g);
	free(gf);
}


void gpio_unexport(int gpio_num)
{
	char buf[1024];
	struct stat s;

	if (gpio_num > MAX_NR_GPIOS || gpio_num < 0) {
		err("Incorrect gpio number %d\n", gpio_num);
		return;
	}

	// Proceed with unexporting the GPIO only if the respective gpioX file is present.
	snprintf(buf, sizeof(buf) - 1, GPIO_DIR_FORMAT_STR, gpio_num);
	if (stat(buf, &s)) {
		dbg("gpio %d not exported\n", gpio_num);
		return;
	}

	dbg("unexporting gpio %d\n", gpio_num);
	snprintf(buf, sizeof(buf) - 1, "%d", gpio_num);
	open_n_write(UNEXPORT_FILE, buf, strlen(buf));
}

gpio_t gpio_aquire(int gpio_num)
{
	char buf[1024];
	struct stat s;
	int ret;
	gpio_t g = NULL;
#ifdef DEBUG
        SET_DEBUG();
#endif
	if (gpio_num > MAX_NR_GPIOS || gpio_num < 0) {
		err("Incorrect gpio number %d\n", gpio_num);
		return NULL;
	}

        snprintf(buf, sizeof(buf) - 1, GPIO_DIR_FORMAT_STR, gpio_num);

	ret = stat(buf, &s);
	if (!ret) {
		// err("GPIO already aquired\n");
		return NULL;
	}
	snprintf(buf, sizeof(buf) - 1, "%d", gpio_num);
	ret = 0;
	dbg("buf = %s\n", buf);
#ifdef STATIC_BUILD_WITH_PTHREAD

	if (!pthread_mutex_lock(&gpio_arr_lock)) {
#endif
		if (!gpios[gpio_num]) {
			g = calloc(1, sizeof(*g));
			gpios[gpio_num] = g;
			if (g) {
				ret = open_n_write(EXPORT_FILE, buf,
							strlen(buf));
				g->gpio_num = gpio_num;
			}
		} else {
			err("gpios[%d] is not NULL\n", gpio_num);
		}
#ifdef STATIC_BUILD_WITH_PTHREAD
		pthread_mutex_unlock(&gpio_arr_lock);
	} else
		err("locking failed\n");
#endif
	if (ret) {
		gpio_release(g);
		g = NULL;
	}
	return g;
}

int gpio_get_dir(gpio_t gpio, int *out)
{
	char dir[4] = {0};
	int rval = 0;

	if (!gpio)
		return -1;
	rval = _direction(0, gpio->gpio_num, dir);
	if (rval) {
		err("getting direction failed\n");
		return rval;
	}
	if (!strcmp("out", dir))
		*out = 1;
	else if (!strcmp("in", dir))
		*out = 0;
	else {
		*out = -1;
		err("Returned value is neither out nor in\n");
		rval = -1;
	}
	return rval;
}

int gpio_set_dir(gpio_t gpio, int out)
{
	char *dir = "out";
	if (!gpio)
		return -1;
	if (!out)
		dir = "in";
	return _direction(1, gpio->gpio_num, dir);
}

int gpio_set_value(gpio_t gpio, int value)
{
	char *sval = "1";
	if (!gpio)
		return -1;
	if (!value)
		sval = "0";
	return _value(1, gpio->gpio_num, sval);
}

int gpio_get_value(gpio_t gpio, int *value)
{
	char sval[4] = {0};
	int rval = 0;

	if (!gpio)
		return -1;

	rval = _value(0, gpio->gpio_num, sval);
	if (rval) {
		err("getting value failed\n");
		return rval;
	}
	if (!strcmp("1", sval))
		*value = 1;
	else if (!strcmp("0", sval))
		*value = 0;
	else {
		*value = -1;
		err("Returned value is neither high nor low\n");
		rval = -1;
	}
	return rval;
}
