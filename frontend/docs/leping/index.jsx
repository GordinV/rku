'use strict';

const React = require('react');
const DocumentRegister = require('./../documents/documents.jsx');
const styles = require('./styles');
const ToolbarContainer = require('./../../components/toolbar-container/toolbar-container.jsx');
const BtnArvesta = require('./../../components/button-register/button-task/index.jsx');
const DOC_TYPE_ID = 'LEPING';

const checkRights = require('./../../../libs/checkRights');
const DocContext = require('./../../doc-context.js');

const DocRights = require('./../../../config/doc_rights');

/**
 * Класс реализует документ справочника признаков.
 */
class Documents extends React.PureComponent {
    constructor(props) {
        super(props);
        this.renderer = this.renderer.bind(this);
        this.onClickHandler = this.onClickHandler.bind(this);

    }

    render() {
        let DOC_TYPE_ID = this.props.module == 'kasutaja' ? 'ISIKU_LEPING' : 'LEPING';
        return (
            <div>
                <DocumentRegister initData={this.props.initData}
                                  history={this.props.history ? this.props.history : null}
                                  module={this.props.module}
                                  ref='register'
                                  docTypeId={DOC_TYPE_ID}
                                  style={styles}
                                  render={this.renderer}/>
            </div>
        );
    }

    renderer(self) {
        if (!self) {
            return null;
        }

        const docRights = DocRights[DOC_TYPE_ID] ? DocRights[DOC_TYPE_ID] : [];
        const userRoles = DocContext.userData ? DocContext.userData.roles : [];

        return (
            <ToolbarContainer>
                {checkRights(userRoles, docRights, 'arved') ?

                <BtnArvesta
                    value={'Koosta arved'}
                    onClick={this.onClickHandler}
                    ref={`btn-koostaArved`}
                    key={`key-koostaArved`}
                />: null}
            </ToolbarContainer>
        );
    }

    //handler для события клик на кнопках панели
    onClickHandler(event, seisuga) {
        let ids = new Set; // сюда пишем ид счетом, которые под обработку
        const Doc = this.refs['register'];

        let message = '';
        // будет сформирован файл для отправки в банк SWED
        Doc.gridData.forEach(row => {
            if (row.select) {
                ids.add(row.id);
            }
        });
        // конвертация в массив
        ids = Array.from(ids);

        if (!ids.length) {
            Doc.setState({
                warning: 'Mitte ühtegi leping valitud', // строка извещений
                warningType: 'notValid',
            });
        } else {
            Doc.fetchData(`calc/koostaArved`, {docs: ids, seisuga: seisuga}).then((data) => {
                if (data.result) {
                    message = `task saadetud täitmisele`;
                    Doc.setState({warning: `${message}`, warningType: 'ok'});

                    let tulemused = data.data.result.tulemused;
                    // открываем отчет
                    this.setState({isReport: true, txtReport: tulemused});

                } else {
                    if (data.error_message) {
                        Doc.setState({warning: `Tekkis viga: ${data.error_message}`, warningType: 'error'});
                    } else {
                        Doc.setState({
                            warning: `Kokku arvestatud : ${data.result}, ${message}`,
                            warningType: 'notValid'
                        });
                    }

                }

            });
        }

    }

    }


module.exports = (Documents);


