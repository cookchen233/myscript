#!/usr/bin/python3

from datetime import datetime, timedelta
import pandas as pd

# for 
class TestSql(object):
    
    sheet_name=""
    filename = ""
    xlsx_pandas: pd.DataFrame
    
    def __init__(self, filename):
        self.filename = filename

    def read_xlsx_pandas(self, sheet_name):
        self.sheet_name = sheet_name
        self.xlsx_pandas = pd.read_excel(self.filename, sheet_name=self.sheet_name, dtype=str)

    def _to_datetime(self, ori_datetime, ori_format="%Y-%m-%d %H:%M:%S"):
            if isinstance(ori_datetime, datetime) is False:
                ori_datetime = datetime.strptime(ori_datetime, ori_format)
            return ori_datetime

    def backup_user(self):
        user_ids = self.xlsx_pandas["注册用户(user_id)"]
        sql="select * from tp_user where user_id in ('{}');".format(str.join("','", user_ids))
        print(sql)
        
    def update_user(self):
        sqls=[]
        for row in self.xlsx_pandas.iloc:
            sql="update tp_user set reg_time='{}' where user_id='{}';".format(self._to_datetime(row["注册时间(reg_date)"]).strftime("%Y-%m-%d %H:%M:%S"), row["注册用户(user_id)"])
            sqls.append(sql)
        print(str.join("\n", sqls))
        
    def backup_order(self):
        order_ids = self.xlsx_pandas["订单号(order_id)"]
        sql="select * from tp_order where order_id in ('{}');".format(str.join("','", order_ids))
        print(sql)

    def update_order(self):
        sqls=[]
        for row in self.xlsx_pandas.iloc:
            order_time = self._to_datetime(row["注册时间(reg_date)"])
            # order_time = order_time + timedelta(days=1)
            sql="update tp_order set order_time='{}',yearmonth='{}', device_id='{}',user_id='{}',source='weixin' where order_id='{}';".format(
                order_time.strftime("%Y-%m-%d %H:%M:%S"), 
                order_time.strftime("%Y%m"), 
                row["设备号(device_id)"],
                row["注册用户(user_id)"],
                row["订单号(order_id)"],
            )
            sqls.append(sql)
        print(str.join("\n", sqls))
    
    def backup_out_device_order(self):
        user_ids = self.xlsx_pandas["注册用户(user_id)"]
        device_id = self.xlsx_pandas["设备号(device_id)"][0]
        sql="select * from tp_order where user_id in ('{}') and device_id <> '{}';".format(str.join("','", user_ids), device_id)
        print(sql)
        
test_sql = TestSql("/Users/Chen/Downloads/测试数据规范_20231106.xlsx")
test_sql.read_xlsx_pandas("非异地075501设备75个")
# test_sql.backup_user()
# test_sql.backup_order()
# test_sql.backup_out_device_order()
#test_sql.update_user()
test_sql.update_order()

test_sql.read_xlsx_pandas("异地补贴077101设备75个")
# test_sql.backup_user()
# test_sql.backup_order()
# test_sql.backup_out_device_order()
# test_sql.update_user()
test_sql.update_order()