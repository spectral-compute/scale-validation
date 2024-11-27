import sys
import time

import pandas
import xgboost

booster = sys.argv[1]
tree_method = sys.argv[2]
name = f'weather {booster} {tree_method}'

# Read the data.
data = pandas.read_csv('weatherHistory.csv')
testingData = data.tail(10000)
trainingData = data.tail(-len(testingData))

# Choose features.
features = ['Temperature (C)', 'Apparent Temperature (C)', 'Humidity', 'Wind Bearing (degrees)', 'Visibility (km)',
            'Loud Cover', 'Pressure (millibars)']
target = 'Wind Speed (km/h)'

print('\x1b[1mTraining data\x1b[m:')
print(trainingData)
print('\x1b[1mChosen features\x1b[m: %s' % ', '.join(features))

# Train.
trainingFeatures = trainingData[features]
trainingTarget = trainingData[target]
regressor=xgboost.XGBRegressor(booster=booster, tree_method=tree_method, device='cuda')

start = time.time()
regressor.fit(trainingFeatures, trainingTarget)
end = time.time()
print('\x1b[1mTime taken to train\x1b[m: %f s (%s)' % (end - start, name))

# Test.
testingInput = testingData[features]

start = time.time()
predictions = regressor.predict(testingInput)
end = time.time()
print('\x1b[1mTime taken to predict\x1b[m: %f s (%s)' % (end - start, name))

# Compare.
predictions = list(predictions)
groundTruth = list(testingData[target])

averageDelta = sum([abs(d[0] - d[1]) for d in zip(predictions, groundTruth)]) / len(predictions)
print('\x1b[1mAverage delta\x1b[m: %f' % averageDelta)

refDeltas = {'gbtree': {'hist': [2.547710], 'approx': [2.532452, 2.547711]},
             'dart':   {'hist': [2.547711], 'approx': [2.532452]}}
refDeltaList = refDeltas[booster][tree_method] # Arch and Ubuntu differ a bit on the results, even on CPU.

deltaBad = True
for refDelta in refDeltaList:
    if (averageDelta >= refDelta - 0.1 and averageDelta <= refDelta + 0.1):
        deltaBad = False
        break
if deltaBad:
    print('\x1b[31;1mAverage delta out of range.\x1b[m: %f %s' % \
          (averageDelta, ', '.join('%f' % d for d in refDeltaList)))
    exit(1)
