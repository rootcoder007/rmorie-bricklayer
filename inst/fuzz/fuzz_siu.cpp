/* libFuzzer target: the SIU report parsers, which read HTML and text fetched
 * from a public site. */
#include <string>
#include "../../src/siu_parse.h"

extern "C" int LLVMFuzzerTestOneInput(const unsigned char *data, size_t size) {
    if (size > 65536) return 0;
    std::string s(reinterpret_cast<const char *>(data), size);
    (void)siu::parse_report_text(s);
    (void)siu::parse_report_html(s);
    return 0;
}
