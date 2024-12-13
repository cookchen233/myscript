from setuptools import setup, find_packages

setup(
    name="alphagen",
    version="0.1",
    packages=find_packages(),
    install_requires=[
        'jinja2',
        'pymysql',
    ],
)
