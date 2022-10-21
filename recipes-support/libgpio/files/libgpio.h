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

#ifndef __GPIOLIB_H__
#define __GPIOLIB_H__

struct gpio;
typedef struct gpio* gpio_t;
typedef enum {IRQ_EDGE_FALLING, IRQ_EDGE_RISING} irq_type_t;
gpio_t gpio_aquire(int gpio_num);
void gpio_unexport(int gpio_num);
void gpio_release(gpio_t gpio);
int gpio_set_dir(gpio_t gpio, int out);
int gpio_get_dir(gpio_t gpio, int *out);
int gpio_set_value(gpio_t gpio, int value);
int gpio_get_value(gpio_t gpio, int *value);
int gpio_set_irq(gpio_t gpio, irq_type_t irq_type);
int gpio_get_irq(gpio_t gpio, irq_type_t *irq_type);
int gpio_wait_for_irq(gpio_t gpio, int timeout);

static int gpio_set_dir_input(gpio_t gpio)
{
	return gpio_set_dir(gpio, 0);
}

static int gpio_set_dir_output(gpio_t gpio)
{
	return gpio_set_dir(gpio, 1);
}
static int gpio_set_value_high(gpio_t gpio)
{
	return gpio_set_value(gpio, 1);
}

static int gpio_set_value_low(gpio_t gpio)
{
	return gpio_set_value(gpio, 0);
}
#endif
