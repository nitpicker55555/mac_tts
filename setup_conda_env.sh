#!/bin/bash

# 创建conda虚拟环境脚本
ENV_NAME="toast_talk_env"

echo "检查conda是否安装..."
if ! command -v conda &> /dev/null; then
    echo "错误: conda未安装。请先安装Anaconda或Miniconda。"
    echo "下载地址: https://www.anaconda.com/products/individual"
    exit 1
fi

echo "创建conda环境: $ENV_NAME"
conda create -n $ENV_NAME python=3.10 -y

echo "激活环境并安装包..."
eval "$(conda shell.bash hook)"
conda activate $ENV_NAME

echo "安装基础绘图包..."
conda install -y numpy pandas matplotlib seaborn plotly scikit-learn jupyter

# 安装额外的有用包
pip install pillow wordcloud

echo "环境创建完成！"
echo ""
echo "环境信息:"
conda info --envs
echo ""
echo "已安装的包:"
conda list

echo ""
echo "环境路径:"
CONDA_PREFIX=$(conda info --base)
echo "Python路径: $CONDA_PREFIX/envs/$ENV_NAME/bin/python"

# 创建配置文件
cat > toast_talk_conda_config.txt << EOF
CONDA_ENV_NAME=$ENV_NAME
PYTHON_PATH=$CONDA_PREFIX/envs/$ENV_NAME/bin/python
EOF

echo ""
echo "配置已保存到 toast_talk_conda_config.txt"