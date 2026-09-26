.pragma library

// hh:mm:ss, as ToyBoxx did; hours past 99 simply grow a digit.
function hms(totalSeconds) {
    const pad = n => n.toString().padStart(2, "0");
    return pad(Math.floor(totalSeconds / 3600)) + ":" + pad(Math.floor(totalSeconds / 60) % 60) + ":" + pad(totalSeconds % 60);
}
