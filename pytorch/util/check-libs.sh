# Symbol is undefined in each libtorch_cuda.so, but just doesn't exist at all in nv dirs.

sym=_ZN2at6native9templates4cuda21uniform_and_transformIN3c104HalfEfPNS_17CUDAGeneratorImplEZZZNS2_16bernoulli_kernelIS7_EEvRNS_18TensorIteratorBaseEdT_ENKUlvE_clEvENKUlvE6_clEvEUlfE_EEvSA_T1_T2_
while read lib; do
    if (nm $lib | grep $sym); then
        echo ">>> $lib"
    fi
done < <(find $1 -name '*.so')
