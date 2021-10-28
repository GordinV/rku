'use strict';

exports.get = async (req, res) => {
    let link = req.params.link; // параметр link
    console.log('link', link)
    res.setHeader("Content-Type", "text/html")
    res.redirect('https://www.avpsoft.ee/')
/*
    res.writeHead(301, {
        Location: "http" + (req.socket.encrypted ? "s" : "") + "://" +
            'www.avpsoft.ee'
    });
    res.end();
*/

/*
    if (link) {
        // вернуть отчет
        res.redirect('http://www.avpsoft.ee');
    }
*/



};
