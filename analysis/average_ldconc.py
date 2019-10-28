import csv
import numpy as np
import pandas as pd
import re

from glob import glob
from matplotlib import pyplot as plt
from os.path import abspath, basename, join
from scipy.stats import binned_statistic

msi = 'min_since_start'
ldconc = 'LD '

bins = np.array([-100, 0, 6, 11.5, 13, 16, 21, 26, 33, 48, 63, 93])

df = pd.read_excel(r'C:\Users\acevedoh\Box\Black_Lab\projects\PD\hysteresis_phMRI\analysis\ld_wrt_infusion_time.xlsx', index_col=[1,3,4]).xs(1, level='scan_day')
df[ldconc] = df[ldconc].astype(float)
df = df.dropna(subset=[ldconc])

x = df['min_since_start'].values
y = df[ldconc].values

means_x = binned_statistic(x, x, statistic='mean', bins=bins).statistic
means_x[0] = 0
means_y = binned_statistic(x, y, statistic='mean', bins=bins).statistic
counts_y = binned_statistic(x, y, statistic='count', bins=bins).statistic
stds_y = binned_statistic(x, y, statistic=lambda x: np.std(x), bins=bins).statistic

rows = [ list(tup) for tup in zip(means_x, means_y, stds_y, counts_y)]
#print(rows)
#empty = np.all(np.isnan(rows) or rows == 0, axis=1)
#print(empty)
#rows = rows[~empty]

with open('binned_average_ldconc.csv', 'w', newline='') as f:
	writer = csv.writer(f)
	writer.writerow(['mean_bin_time', 'mean_val', 'std_val', 'n'])
	writer.writerows(rows)

marker_sizes = [ 2000* (n / sum(counts_y)) for n in counts_y ]

plt.figure(figsize=(10,4))

plt.scatter(means_x, means_y, s=marker_sizes, alpha=.5)
#plt.errorbar(means_x, means_y, yerr=stds_y, capsize=2)

plt.xlabel('Minutes since infusion')
#plt.xlim(-100,100)
#plt.ylim(y_lims[0], y_lims[1])
plt.ylabel('[LD]')
plt.title('Average [LD]')
plt.savefig('binned_average_ldconc.png')
