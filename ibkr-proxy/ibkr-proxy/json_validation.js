export default { checkRequestBodyLength };

function checkRequestBodyLength(r) {
    try {
        if (r.variables.request_body) {
            if (JSON.parse(r.variables.request_body).length <= 200) {
                return r.variables.upstream;
            }
        }
        r.return(413, "Maximum of 200 conids supported."); r.finish(); return "@invalid"
    } catch (e) {
        r.return(400, "Bad request."); r.finish(); return "@invalid"
    }
}