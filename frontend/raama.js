'use strict';

const ReactDOM = require('react-dom');
const {BrowserRouter} = require('react-router-dom');
import DocContext from './doc-context.js';

const Doc = require('../frontend/modules/raama.jsx');

initData = JSON.parse(initData);
userData = JSON.parse(userData);

// сохраним базовые данные в памети

DocContext.initData = initData;
DocContext.userData = userData;
DocContext.module = 'raama';
DocContext.pageName = 'Raamatupidamine';
DocContext.gridConfig = initData.docConfig;
DocContext.menu = initData.menu ? initData.menu.data : [];


ReactDOM.hydrate(
    <BrowserRouter>
        <Doc initData={initData}  userData={userData}/>
    </BrowserRouter>
    , document.getElementById('doc')
);

