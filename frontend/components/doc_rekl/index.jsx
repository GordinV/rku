'use strict';

const PropTypes = require('prop-types');
const fetchData = require('./../../../libs/fetchData');
const DocContext = require('./../../doc-context.js');

//const {withRouter} = require('react-router-dom');

const React = require('react'),
    styles = require('./styles');

class Index extends React.PureComponent {
    constructor(props) {
        super(props);
        this.docId = null;
        this.state = {
            nimetus: null,
            link: null
        };
        this.interval = null;
        this.fetchData = this.fetchData.bind(this);

    }

    componentDidMount() {
//        setInterval(this.fetchData(), 1000 * 60);
        this.interval = setInterval(() => this.fetchData(), 30000);

    }

    componentWillUnmount() {
        clearInterval(this.interval);
    }

    render() {
        return (
            <div style={styles.frame}>
                <br/>
                {this.state.nimetus ?
                    <button
                        onClick={() => {
                            DocContext.link = this.state.link;
                            const current = `/kasutaja`;
                            this.props.history.replace({
                                pathname: `/redirect`,
                                state: {link: `${this.state.link}`}
                            });
                            setTimeout(() => {
                                this.props.history.replace(current);
                            }, 10000)
                        }

                        }>
                        {this.state.nimetus}
                    </button>
                    : null}
            </div>
        )
    };


    /**
     * Выполнит запросы
     */
    fetchData(url, link) {
        let URL = `/newApi`;
        if (link) {
            URL = link;
        }

        let params = {
            link: link,
            parameter: 'REKL', // параметры
            method: 'selectDocs',
            sortBy: [{column: 'last_shown', direction: 'asc'}], // сортировка
            limit: 1, // row limit in query
            sqlWhere: 'where (alg_kpv::date <= current_date or lopp_kpv::date >= current_date) AND docs.update_last_rekl(id) = 1', // динамический фильтр грида
            module: 'juht',
            userId: DocContext.userData.userId,
            uuid: DocContext.userData.uuid,
        };

        return new Promise((resolved, rejected) => {
            if (link) {
                fetchData['fetchDataGet'](URL);
            } else {
                fetchData['fetchDataPost'](URL, params).then(response => {
                    if (response.status && response.status === 401) {
                        document.location = `/login`;
                    }

                    // error handling
                    if (response.status !== 200) {
                        return {
                            result: null,
                            status: response.status,
                            error_message: `error ${(response.data && response.data.error_message) ? 'response.data.error_message' : response.error_message}`
                        }
                    }

                    let data = response.data.result.data[0];
                    this.setState({nimetus: data.nimetus, link: data.link});
                    resolved(response.data);
                })
            }
        }).catch((error) => {
            console.error('fetch error', error);
            // Something happened in setting up the request that triggered an Error
        });
    }

}

//module.exports = withRouter(DocToolBar);
module.exports = Index;