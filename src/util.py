def standardize_PIT(x):
    position = x.find('.')
    if position != 3:
        prefix_string = x[position-3:position]
        before_prefix = x[0:position-3]
        period_string = x[position:]
        final_string = prefix_string + period_string + before_prefix
        return final_string
    else:
        return(x)