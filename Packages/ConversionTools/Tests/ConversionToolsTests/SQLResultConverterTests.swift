import XCTest
@testable import ConversionTools

final class SQLResultConverterTests: XCTestCase {
    let sample = """
    +--------+---------------+----------------------+-------------------------+--------+--------------+
    | id     | old_client_id | new_client_id        | url                     | name   | use_new_auth |
    +--------+---------------+----------------------+-------------------------+--------+--------------+
    |   1251 | NULL          | 19e2bb5250900bb59501 | devtest.kingdee.com     | Lingee |            1 |
    |  22553 | NULL          | 19e2bb5250900bb59501 | kdm.lingeeglobal.ai     | Lingee |            1 |
    +--------+---------------+----------------------+-------------------------+--------+--------------+
    """

    func testParseColumnsAndRows() {
        let table = SQLResultConverter.parse(sample)
        XCTAssertNotNil(table)
        XCTAssertEqual(table?.columns, ["id", "old_client_id", "new_client_id", "url", "name", "use_new_auth"])
        XCTAssertEqual(table?.rows.count, 2)
        XCTAssertEqual(table?.rows[0][0], "1251")
        XCTAssertEqual(table?.rows[0][3], "devtest.kingdee.com")
    }

    func testCSV() {
        let table = SQLResultConverter.parse(sample)!
        let csv = SQLResultConverter.toCSV(table)
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "id,old_client_id,new_client_id,url,name,use_new_auth")
        // NULL becomes empty in CSV.
        XCTAssertEqual(lines[1], "1251,,19e2bb5250900bb59501,devtest.kingdee.com,Lingee,1")
    }

    func testInsert() {
        let table = SQLResultConverter.parse(sample)!
        let insert = SQLResultConverter.toInsert(table, tableName: "dt_app_domain")
        XCTAssertTrue(insert.hasPrefix("INSERT INTO `dt_app_domain` (`id`, `old_client_id`,"))
        XCTAssertTrue(insert.contains("(1251, NULL, '19e2bb5250900bb59501', 'devtest.kingdee.com', 'Lingee', 1)"))
        XCTAssertTrue(insert.hasSuffix(";"))
    }

    func testUpdate() {
        let table = SQLResultConverter.parse(sample)!
        let update = SQLResultConverter.toUpdate(table, tableName: "dt_app_domain", keyColumn: "id")
        let lines = update.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("UPDATE `dt_app_domain` SET "))
        XCTAssertTrue(lines[0].contains("`url` = 'devtest.kingdee.com'"))
        XCTAssertTrue(lines[0].contains("`old_client_id` = NULL"))
        XCTAssertTrue(lines[0].hasSuffix("WHERE `id` = 1251;"))
        // Key column should not appear in the SET clause.
        XCTAssertFalse(lines[0].contains("SET `id`"))
    }

    func testStringEscaping() {
        let input = """
        +----+----------+
        | id | note     |
        +----+----------+
        |  1 | O'Brien  |
        +----+----------+
        """
        let table = SQLResultConverter.parse(input)!
        let insert = SQLResultConverter.toInsert(table, tableName: "t")
        XCTAssertTrue(insert.contains("'O''Brien'"))
    }

    func testParseTableNameFromSelect() {
        let q = "mysql> select * from dt_app_domain where new_client_id='x';"
        XCTAssertEqual(SQLResultConverter.parseTableName(q), "dt_app_domain")
    }

    func testParseTableNameFromUpdateAndInsert() {
        XCTAssertEqual(SQLResultConverter.parseTableName("UPDATE `users` SET a=1"), "users")
        XCTAssertEqual(SQLResultConverter.parseTableName("insert into orders (id) values (1)"), "orders")
    }

    func testParseTableNameNoneReturnsNil() {
        XCTAssertNil(SQLResultConverter.parseTableName("+----+\n| id |\n+----+"))
    }

    func testParseTableNameFullPaste() {
        // The user's real paste: query line + result table together.
        let full = "mysql> select * from dt_app_domain where new_client_id='19e2bb';\n" + sample
        XCTAssertEqual(SQLResultConverter.parseTableName(full), "dt_app_domain")
        XCTAssertNotNil(SQLResultConverter.parse(full))
    }

    func testTabSeparatedFallback() {
        let tsv = "id\tname\n1\tAlice\n2\tBob"
        let table = SQLResultConverter.parse(tsv)
        XCTAssertEqual(table?.columns, ["id", "name"])
        XCTAssertEqual(table?.rows.count, 2)
    }
}
