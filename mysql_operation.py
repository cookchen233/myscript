#!/usr/bin/python3

import pymysql, sys, time
args = sys.argv

class Mydata(object):
    
    pymysql_connection: pymysql.Connection
    
    def __init__(self):
        self.pymysql_connection = pymysql.connect(host='localhost', port=3306, user='root', password='', db='mydata', charset='utf8')
        
    def __del__(self):
        if hasattr(self, 'pymysql_connection') and self.pymysql_connection:
            self.pymysql_connection.close()
        
    def _execute(self, sql, *kwargs):
        # print("================================================")
        with self.pymysql_connection.cursor() as cursor:
            cursor.execute(sql, kwargs)
            self.pymysql_connection.commit()
            
    def _get_row_from_cursor(self, cursor):
        column_names = [column[0] for column in cursor.description]
        result = cursor.fetchone()
        if result:
            return dict(zip(column_names, result))
        else:
            return None
        
    def _get_rows_from_cursor(self, cursor):
        column_names = [column[0] for column in cursor.description]
        result = cursor.fetchall()
        rows = []
        for row in result:
            rows.append(dict(zip(column_names, row)))
        return rows
            
    def _get_columns_from_cursor(self, cursor, column_name):
        columns = [desc[0] for desc in cursor.description]
        result = cursor.fetchall()
        if column_name in columns:
            column_index = columns.index(column_name)
            return [row[column_index] for row in result]
        return []
class CommandLog(Mydata):
    
    table_name = "command_log"
    
    def createIgnoreSame(self):
        time.sleep(0.1)
        with open('/Users/Chen/Coding/myscript/test.sh', 'r') as file:
            lines = file.readlines()
        new_lines = []
        found_code = False
        for line in lines:
            if line.strip().startswith('#') and not found_code:
                continue
            elif line.strip() and not found_code:
                found_code = True
            if found_code:
                new_lines.append(line)

        new_content="\n".join(new_lines)
        last_one=self.get_last_one()
        if last_one and last_one["content"] == new_content:
            return 0
        sql = "INSERT INTO "+ self.table_name +" (title, content) VALUES (%s, %s)"
        return self._execute(sql, new_content, new_content)
        
    def get_last_one(self):
        with self.pymysql_connection.cursor() as cursor:
            query = f"select * from `{self.table_name}` order by id desc limit 1"
            cursor.execute(query)
            return self._get_row_from_cursor(cursor)
        
    def get_recent_commands(self):
        with self.pymysql_connection.cursor() as cursor:
            query = f"SELECT * FROM ( SELECT * FROM `{self.table_name}` ORDER BY id DESC LIMIT 5 ) AS subquery ORDER BY id ASC"
            cursor.execute(query)
            return self._get_columns_from_cursor(cursor, "title")

if args[1] == "create_command_log":
    command_log = CommandLog()
    command_log.createIgnoreSame()

elif args[1] == "get_recent_commands":
    command_log = CommandLog()
    print("\n".join(command_log.get_recent_commands()))
    