#!/bin/bash

perl -ne 'print $1, "\n" if /^test_[\w\d_]* \(__main__\.([\w\d_]*cuda[\d\w_]*\.[\w\d_]+)/i' $1
