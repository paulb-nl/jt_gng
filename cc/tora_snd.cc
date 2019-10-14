#include <iostream>
// find closest rational number to get the FM frequency off a 48MHz clock
// Result: 105/1408 = 3,579,545.5 MHz, off by 0.5Hz (0.14ppm) :-)

using namespace std;

const float ref   = 3579545;
const float fbase = 48000000;

int main() {
    float best=ref;
    for( float d=1; d<100000; d++) {
        for( float n=1; n<d; n++ ) {
            bool neg=false;
            float r = n/d*fbase;
            float err = r-ref;
            if(err<0) {
                neg = true;
                err=-1*err;
            }
            if( err < best ) {
                best = err;
                cout << n << " / " << d << " = " << r << " ( " << err << " )\n";
            }
            //else {
            //    cout << r << " = " << n << " *** " << d << '\n';                
            //}
            if(!neg) break;
        }
    }
}