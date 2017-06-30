from distutils.core import setup
from Cython.Build import cythonize

setup(
    ext_modules = cythonize("FVS_localsearch_10_cython.pyx")
)

'''
setup(
    ext_modules = cythonize("FVS_localsearch_8_cython.pyx",
  #sources=[""], #add additional source file
  language = "c++"))
'''
