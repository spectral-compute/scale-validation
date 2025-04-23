import datetime
import sys

# Usage: IsoTimestampDiff.py Start End [StartIdx] [EndIdx]
# If the indices are specified then the corresponding start/end argument is treated as a newline separated list, and the
# index specifies which line is wanted (it's used in a Python slice, so negative values are permitted).

start = sys.argv[1]
if len(sys.argv) > 3:
    start = start.split('\n')[int(sys.argv[3])]

end = sys.argv[2]
if len(sys.argv) > 4:
    end = end.split('\n')[int(sys.argv[4])]

print((datetime.datetime.fromisoformat(end) - datetime.datetime.fromisoformat(start)).total_seconds())
