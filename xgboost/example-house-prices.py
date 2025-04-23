# Based on https://www.kaggle.com/code/carlmcbrideellis/xgboost-benchmark/notebook.
import sys
import time

import pandas
import xgboost

booster = sys.argv[1]
tree_method = sys.argv[2]
name = f'house prices {booster} {tree_method}'

# Read the data.
trainingData = pandas.read_csv('train.csv')

# Choose features.
trainingData = trainingData.select_dtypes(include=['number'])
features = [f for f in list(trainingData.columns) if f not in ['Id', 'SalePrice']]

print('\x1b[1mTraining data\x1b[m:')
print(trainingData)
print('\x1b[1mChosen features\x1b[m: %s' % ', '.join(features))

# Train.
trainingFeatures = trainingData[features]
trainingTarget = trainingData['SalePrice']
regressor=xgboost.XGBRegressor(booster=booster, tree_method=tree_method, device='cuda')

start = time.time()
regressor.fit(trainingFeatures, trainingTarget)
end = time.time()
print('\x1b[1mTime taken to train\x1b[m: %f s (%s)' % (end - start, name))

# Test.
testingData  = pandas.read_csv('test.csv')
testingInput = testingData[features]

start = time.time()
predictions = regressor.predict(testingInput)
end = time.time()
print('\x1b[1mTime taken to predict\x1b[m: %f s (%s)' % (end - start, name))

# Output.
print('\x1b[1mPredictions\x1b[m:')
print(predictions)
output = pandas.DataFrame({'Id': testingData.Id, 'SalePrice': predictions})
output.to_csv('out.csv', index=False)

# Compare.
predictions = list(predictions)
submissionPredictions = list(pandas.read_csv('submission.csv')['SalePrice'])

bad = False
if len(submissionPredictions) != len(predictions):
    print('\x1b[31;1mWrong number of predictions.\x1b[m')
    bad = True

averageDelta = sum([abs(d[0] - d[1]) for d in zip(predictions, submissionPredictions)]) / len(predictions)
print('\x1b[1mAverage delta\x1b[m: %f' % averageDelta)

refDeltas = {'gbtree': {'hist': [11348.786164, 11314.406732], 'approx': [11348.786164, 11314.406732]},
             'dart':   {'hist': [11348.788059, 11314.404208], 'approx': [11348.788059, 11314.404208]}}
refDeltaList = refDeltas[booster][tree_method] # Arch and Ubuntu differ a bit on the results, even on CPU.

deltaBad = True
for refDelta in refDeltaList:
    if (averageDelta >= refDelta - 0.1 and averageDelta <= refDelta + 0.1):
        deltaBad = False
        break
if deltaBad:
    print('\x1b[31;1mAverage delta out of range.\x1b[m: %f %s' % \
          (averageDelta, ', '.join('%f' % d for d in refDeltaList)))
    bad = True

if bad:
    exit(1)
