// -- check out myTest.ts -- after downloaded next run no downloadede require
// uses esm.sh else upkg load long and stuck / use deno install (will save in cache - use deno info to check path)
//

import { format } from "https://esm.sh/date-fns@3.6.0/format";
import { format as uformat } from "https://unpkg.com/date-fns@3.6.0/format.mjs";
import { getHours } from "https://esm.sh/date-fns@3.6.0/getHours";
//app.unpkg.com/date-fns@3.6.0 # see docs and available files

const formattedDate = format(new Date(), "yyyy-MM-dd");
const uformattedDate = uformat(new Date(), "yyyy-MM-dd");
console.log(formattedDate);
console.log(uformattedDate);

// getHours
console.log(getHours(new Date()));
console.log(getHours(new Date("asdasd")));
